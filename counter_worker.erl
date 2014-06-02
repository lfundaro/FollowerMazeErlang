-module(counter_worker).
-compile(export_all).

-record(state, {msgBuffer=[],
				startSeq=1}).

init() ->
	io:format("Counter worker started~n"),
	loop(#state{}).
	
loop(S = #state{}) ->
	receive
		{new_event,CurrentSeq,ReplyTo} ->
			SS = S#state{msgBuffer = addNewSeq(S#state.msgBuffer,CurrentSeq)},
			case checkForFlush(SS) of
				{true,From,To,NewMsgBuffer,NewStartSeq} ->
					ReplyTo ! {call_flush,From,To},
					loop(SS#state{msgBuffer=NewMsgBuffer,startSeq=NewStartSeq});
				{false} -> loop(SS)
			end;
		_ -> loop(S)
	end.
	
addNewSeq(Buffer, CurrentSeq) ->
	utils:insertNumber(CurrentSeq, Buffer).
	
checkForFlush(S = #state{}) ->
	From = S#state.startSeq,
	MsgBuffer = S#state.msgBuffer,
	% io:format("Current msg buffer: ~p~n",[MsgBuffer]),
	{To,NewMsgBuffer} = dropForFlush(From,MsgBuffer),
	if To =:= From ->    %Nothing changed
		{false};
	   To =/= From ->
		{true,From,To-1,NewMsgBuffer,To}
	end.
	
dropForFlush(To,[]) -> {To,[]};
dropForFlush(To, L = [H|T]) -> 
	if To =:= H -> 
		dropForFlush(To+1,T);
	   To =/= H -> 
		{To, L}
	end.
	