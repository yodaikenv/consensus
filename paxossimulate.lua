--[[  Terribly written ugly lua code that simulates Paxos multi-proposer
-- The file paxos.data has the configuration
-- We try for multiple sizes of the set of Acceptors, incrementing by 2 each
-- time until the limit

(c) Victor Yodaiken 2016

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
---]] 


dofile("paxos.data") -- read in parameters in a structure T
 
--- globals for the game
p = {} --- proposers
a = {} --- acceptors
stat = {} --- game stats

function count(x,n)  --- how many non-nil entries up to n are in array x
	local c =0
	for i=0, n do if x[i] ~= nil then c = c+1 end end 
	return c;
end 

function displayproposers(m,axes) --print out proposer key values
local v = nil
print(m,"-------------------")
for i=1,T.proposers do
	print(i,"id=", p[i].id, "phase=",
		 p[i].phase, "v=",p[i].value, count(p[i].approved,axes),
		count(p[i].accepted,axes))
	if p[i].phase == 3 then
		if v == nil then v = p[i].value elseif v ~= p[i].value then
			print("failed")
		end
	end
end
end

function statinit(numberofacceptors)
	stat = {
	runs =0,
	failures =0 ,
	livelocks = 0,
	winners = 0,
	winning = 0,
        acceptors = numberofacceptors,
	sumofvalues =0 }
end

function stats(axes)
	local winners=0
        local value = nil
	local fails = 0

	for i=1,T.proposers do
		if p[i].phase == 3 then 
			winners = winners+1
			if value == nil then value = p[i].value
			elseif value ~= p[i].value then fails = 1 
                	end
		end
	end
	stat.runs = stat.runs +1
	if winners == 0 then stat.livelocks = stat.livelocks +1 
	else
		stat.winners = stat.winners + winners
		stat.winning = stat.winning +1
		stat.sumofvalues = stat.sumofvalues + value
	end
	if fails == 1 then 
		stat.failures = stat.failures +1
		displayproposers("stat failure",axes)
	end
end

function displaystats()
	print("This test ----------------------\n")
	print("Acceptors=",stat.acceptors,
        "Average winning id=", string.format("%.2f",stat.sumofvalues/stat.winning),
        "\nChance of livelock=", stat.livelocks/stat.runs,
         "Rounds without consensus=", T.rounds - stat.winning)
end 
	     

			
 
	

function setretry(n)
  p[n].retries = p[n].retries +1
  if p[n].retries > T.retries then 
	local id = p[n].id
	initonep(n)
	p[n].id = id + T.proposers
  end 
end

function pickvalue(n) 
	local v
	if p[n].bestv ~= nil then v= p[n].bestv else v= p[n].id end
	return v
end

function newapproval(px,ax,numa)
	local t = a[ax].highestq
	local z = p[px].id
	if p[px].approved[ax] == nil and a[ax].highestq <= p[px].id then --ifq
		p[px].approved[ax]=1;	
		a[ax].highestq = p[px].id
                if p[px].bestq < a[ax].bestq then
			p[px].bestq = a[ax].bestq
			p[px].bestv = a[ax].bestv
		end
		if count(p[px].approved, numa) > numa/2 then --ifcount
			p[px].phase =2
			p[px].value = pickvalue(px)
			p[px].retries =0 --approval starts fresh
		end --ifcount
	p[px].retries =0
	return true
	end --ifq
return false
end

function newaccept(px,ax,numa)
	if p[px].accepted[ax] == nil and a[ax].highestq <= p[px].id then --ifq
		p[px].accepted[ax]=1;	
		if a[ax].bestq < p[px].id then 
			a[ax].bestq = p[px].id
			a[ax].bestv = p[px].value
		end
		if count(p[px].accepted, numa) > numa/2 then
			p[px].phase =3
		end --count
		p[px].retries =0
		return true
	end --ifq
return false
end

function initp()
for i=1, T.proposers do initonep(i) end
end

function initonep(i)
	p[i] ={ id=i, retries=0, phase=1, approved= {}, accepted={},value=nil, bestv=nil, bestq=0}
end

function inita()
for i=1,T.maxacceptors do
	a[i] = { id = i, highestq = 0, bestv = nil, bestq= 0 } end
end

function nextproposer()
	local x= (math.floor((math.random()* T.proposers) +1 )% T.proposers )+1
return x
end

function nextacceptor(n)
	return (math.floor((math.random()* n) +1 )% n )+1	
end
	
-- main 
math.randomseed(os.time())

print("Simulate Paxos Consensus with increasing numbers of acceptors\n");
print("Proposers=",T.proposers,"\nTime per round =",T.timeperround, " Rounds=",T.rounds, " Retries=",T.retries)
for n= T.acceptors,  T.maxacceptors,2 do --foracceptors
	statinit(n)
	for round = 1, T.rounds do --forround
		initp(); inita(); 
		for t=1, T.timeperround do --fortime
			local px =  nextproposer() 
			local ax = nextacceptor(n)
			if p[px].phase == 1 then --ifphase
				if newapproval(px,ax,n) == false then setretry(px) end
			elseif p[px].phase == 2 then --ifphase2
				if newaccept(px,ax,n) == false then setretry(px) end
			end --ifphase2 and phase1
		end --fortime
		stats(n)
	end --forround
displaystats()
end
print("Ax\tLlock%\tWinning\tAvg value")






