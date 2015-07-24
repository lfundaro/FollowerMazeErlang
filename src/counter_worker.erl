-module(counter_worker).
-include("eventMessage.hrl").
-export([init/0,loop/1,checkForFlush/1,dropForFlush/3,insertMsg/2,insertMsgTailRec/3]).

% This records maintains the following structures:
	% - msgBuffer: a list containing all the messages that have been received 
				% and that might be subject to flushing (when a slice of the list 
				% corresponds to an ordered sequence).
	% - startSeq: an integer that indicates the number of the new sequence that 
				% has to be processed. 
-record(state, {msgBuffer=[],
				startSeq=1}).

init() ->
	process_flag(trap_exit, true),
	loop(#state{}).
	
% The core function of the counter worker is to buffer messages that 
% have been received and try to flush them when an ordered sequence is found. 
% Starting from startSeq=1 means that the firts sequence that has to be processed 
% is the number one. For each new message received, the counter_worker checks 
% if an ordered sequence can be found starting from startSeq. If that is the case 
% then counter_worker sends a message to Dispatcher (see dispatcher.erl) to process 
% the messages. Finally, it listens for a shutdown signal so it exits nicely.
loop(S = #state{}) ->
	receive
		{new_event,M,ReplyTo} ->
			NewState = S#state{msgBuffer=insertMsg(M, S#state.msgBuffer)},
			case checkForFlush(NewState) of
				{true,NewStartSeq,MessagesToProcess,Remaining} ->
					ReplyTo ! {process_messages,MessagesToProcess},
					loop(NewState#state{msgBuffer=Remaining,startSeq=NewStartSeq});
				{false} -> loop(NewState)
			end;
		{'EXIT', _, shutdown} -> 
			exit(normal);
		_ -> loop(S)
	end.
	
% This function checks if there exists an ordered sequence in 
% the messsage buffer that can be send to the dispatcher. Returns 
% a new startSeq (to start from next time this function is called), a 
% possible ordered subset of the msgBuffer, and the remaining messages 
% that still need certain elements to complete an ordered sequence.
checkForFlush(S = #state{}) ->
	From = S#state.startSeq,
	MsgBuffer = S#state.msgBuffer,
	{To,NewMsgBuffer,Remaining} = dropForFlush(From,[],MsgBuffer),
	if To =:= From ->    %Nothing changed
		{false};
	   To =/= From ->
		{true,To,NewMsgBuffer,Remaining}
	end.
	
% Helper function of checkForFlush
dropForFlush(To,Acc,[]) -> {To,lists:reverse(Acc),[]};
dropForFlush(To, Acc, L = [H|T]) -> 
	if To =:= H#eventMessage.seq -> 
		dropForFlush(To+1,[H|Acc],T);
	   To =/= H#eventMessage.seq -> 
		{To, lists:reverse(Acc), L}
	end.

% Inserts a message on a list. It does an online insertion 
% algorithm. 
insertMsg(M = #eventMessage{}, []) -> [M];
insertMsg(M = #eventMessage{}, [H|T]) -> 
	if M#eventMessage.seq < H#eventMessage.seq -> 
			[M|[H|T]];
	   M#eventMessage.seq > H#eventMessage.seq -> 
			insertMsgTailRec(M, T, [H]);
		true ->
			[H|T]
	end.
	
insertMsgTailRec(M = #eventMessage{}, [], Acc) -> Acc ++ [M]; 
insertMsgTailRec(M = #eventMessage{}, [H|T], Acc) ->
	if M#eventMessage.seq < H#eventMessage.seq -> 
			Acc ++ [M|[H|T]];
	   M#eventMessage.seq > H#eventMessage.seq -> 
			insertMsgTailRec(M, T, Acc ++ [H]);
	   true ->
			Acc ++ [H|T]
	end.
	