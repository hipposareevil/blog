+++
title = "Threads and Processes"
date = "2004-03-30"
draft = false
tags = ["work"]
categories = ["work"]
summary = "One of my projects at work is a data server that uses SOAP as its communication protocol. A year ago I tried, unsuccessfully, to make the server multi-threaded."
+++

One of my projects at work is a data server that uses <a href="http://www.w3.org/TR/SOAP/">SOAP</a> as its communication protocol.  A year ago I tried, unsuccessfully, to make the server multi-threaded.  This was a bust because in C++ the support libraries are not thread-safe.  So I spent over 3 months trying to fix this and got no where.

A co-worker stumbled upon <a href="http://www.stlport.org/">STLport</a>, a thread-safe STL implementation.  It was supposed to be faster than the normal STL, and in our micro-benchmarking, it was.
I re-enabled the server to be multi-threaded with the snazzy STLport and expected the program to scale better, that is to say, handle more concurrent clients without performance degredation.  And it sucked.  We actually had a slower performing program.  2 weeks later we realized that STLport was in fact two times as slow as the normal STL when it was run in a threaded environment.  Super.  The threads helped the scalability a bit, but couldn't over come the slow STL.

Another option was to use a Apache module and have the server plug into an Apache process.  I spent about 3 days working on that before I realized it wasn't going to be smooth because the support wasn't really there.

I decided to take the Apache process model and apply it to my server.  Old school programmers would normally do a fork()/exec() for each incoming request, letting the child process handle the request.  This isn't so great because it's expensive to spawn a new process for each small request.  So instead, I used a different model of just spawning multiple processes at the beginning that all listen on the same port.

When it came to testing this out, we saw a whopping gain of 18% when using multiple clients.  Why so slow?  HP-UX is my reason.  The CPU is maxed out with one process and we max out both CPUs when multiple processes are running.  This should gain you about 80% (a guess, really) performance gain owing to the increased CPU time.  But HP strikes again and you only see a 18% gain.  There must be another bottleneck, like the memory, disk or bus.  Really lame.

It's kinda funny to spend over 4 months on a project to see a net result of 18% for all of your work.  I keep telling anyone who listens that we need to ditch <a href="http://www.hp.com">HP</a> and get some <a href="http://www.redhat.com/">Linux</a> boxes.  I get nods of the head, but I guess we're not in a position to come and use present day technology.
