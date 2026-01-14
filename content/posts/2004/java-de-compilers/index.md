+++
title = "Java De-Compilers"
date = "2004-01-22"
draft = false
tags = ["nerd"]
categories = ["work"]
summary = "Yesterday I was working on some code and did a cvs merge and lost some of my code during a conflict. So I used a Java decompiler to get the source code for my last build."
+++

Yesterday I was working on some code and did a <a href="http://www.gnu.org/software/cvs/">cvs</a> merge and lost some of my code during a conflict.  So I used a <a href="http://www.spiderpro.com/bu/bujavt002.html">Java decompiler</a> to get the source code for my last build.

It had all of the code that I had lost so I could just copy the correct code back over.  What was interesting was the type of optimizations the compiler made.  It was either the compiler or the decompiler misreading the bytecode (I figure it's the compiler.)

My original code had a while loop like this:
<code>
while (iter.hasNext())
{
SummaryObject obj = (SummaryObject) iter.next();
SummaryObject newObj = obj.newInstance();
newObj.setGroup(currGroup);
newSummaryObjs.add(newObj);
}
</code>

While the decompiled code was:
<code>
SummaryObject newObj;
for(; iter.hasNext(); newSummaryObjs.add(newObj))
{
SummaryObject obj = (SummaryObject)iter.next();
newObj = obj.newInstance();
newObj.setGroup(currGroup);
}
</code>

It looked like all while loops were turned into for loops.  Interesting to see how the compiler would optimize things.
