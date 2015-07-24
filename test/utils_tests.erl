-module(utils_tests).
-include_lib("eunit/include/eunit.hrl").
-include("eventMessage.hrl").

run_test_() ->
	[parse_input_test(),
	seqToInt_test(),
	tokenize_test(),
	typeOfMsg_test()].

parse_input_test() ->
	[?_assertEqual(undefined, utils:parse_input(<<"123|Z|45|2\r\n">>)),
	?_assertEqual(#eventMessage{payload=(<<"123|F|45|2\r\n">>),
							  seq=123,
							  type=follow,
							  fromUser="45",
							  toUser="2"},utils:parse_input(<<"123|F|45|2\r\n">>)),
	?_assertEqual(#eventMessage{payload=(<<"34|B\r\n">>),
							  seq=34,
							  type=broadcast},
							  utils:parse_input(<<"34|B\r\n">>)),
	?_assertEqual(#eventMessage{payload=(<<"100|S|4\r\n">>),
							  seq=100,
							  type=status_update,
							  fromUser="4"},
							  utils:parse_input(<<"100|S|4\r\n">>)),
	?_assertEqual("1254",utils:parse_input(<<"1254\r\n">>))].
	
seqToInt_test() ->
	[?_assertEqual(34,utils:seqToInt("34"))].
	
tokenize_test() ->
	[?_assertEqual(["56","F","78","3"],utils:tokenize(<<"56|F|78|3\r\n">>)),
	?_assertEqual(["12","B"],utils:tokenize(<<"12|B\r\n">>))].
	
typeOfMsg_test() ->
	[?_assertEqual(follow,utils:typeOfMsg(#eventMessage{type=follow}))].
	
	