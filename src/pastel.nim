# Copyright (c) 2019 zenywallet

import server
import stream

var threads: array[2, Thread[void]]
threads[0] = server.start()
threads[1] = stream.start()
joinThreads(threads)
