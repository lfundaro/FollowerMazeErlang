-module(counter_worker_tests).
-include_lib("eunit/include/eunit.hrl").
-include("../include/eventMessage.hrl").

run_test_() ->
	[insertMsg_test(),
	dropForFlush_test()].

insertMsg_test() ->
	[?_assertEqual([#eventMessage{}],counter_worker:insertMsg(#eventMessage{},[])),
	?_assertEqual([#eventMessage{seq=10},#eventMessage{seq=12}],counter_worker:insertMsg(#eventMessage{seq=12},[#eventMessage{seq=10}])),
	?_assertEqual([#eventMessage{seq=12}],counter_worker:insertMsg(#eventMessage{seq=12},[#eventMessage{seq=12}])),
	?_assertEqual([#eventMessage{seq=2},#eventMessage{seq=16}],counter_worker:insertMsg(#eventMessage{seq=2},[#eventMessage{seq=16}]))].
	
dropForFlush_test() ->
	[?_assertEqual({1,[],[#eventMessage{seq=2}]},counter_worker:dropForFlush(1,[],[#eventMessage{seq=2}])),
	?_assertEqual({3,[#eventMessage{seq=1},#eventMessage{seq=2}],[]},counter_worker:dropForFlush(1,[],[#eventMessage{seq=1},#eventMessage{seq=2}])),
	?_assertEqual({3,[#eventMessage{seq=1},#eventMessage{seq=2}],[#eventMessage{seq=4}]},counter_worker:dropForFlush(1,[],[#eventMessage{seq=1},#eventMessage{seq=2},#eventMessage{seq=4}]))].
	

	
