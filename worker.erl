-module(worker).
-include("eventMessage.hrl").
-compile(export_all).

-record(state, {lastSeq=-1,
			    clientSocket,
				msgBuffer=[],
				followers=dict:new()
				}).

init(Socket) ->
	% io:format("New Worker started~n"),
	loop(#state{clientSocket=Socket}).
	
loop(S = #state{}) -> 
	receive
		{follow,MsgCount,M = #eventMessage{},FollowerPid} ->
			loop(handleFollow(S,MsgCount,M,FollowerPid));
		{follow,MsgCount,M = #eventMessage{}} ->
			loop(handleFollow(S,MsgCount,M));
		{unfollow,M = #eventMessage{}} ->
			loop(handleUnfollow(S,M));
		{broadcast,MsgCount,M = #eventMessage{}} ->
			loop(handleBroadcast(S, MsgCount, M));
		{private_message,MsgCount,M = #eventMessage{}} ->
			loop(handlePrivateMsg(S,MsgCount,M));
		{status_update,MsgCount,M = #eventMessage{}} ->
			loop(handleStatusUpdate(S,MsgCount,M));
		_ -> loop(S)   %ignore any other message.
	end.
	
handleStatusUpdate(S = #state{}, MsgCount,M = #eventMessage{}) ->
	SS = S#state{msgBuffer=insertMsg(M, S#state.msgBuffer)},  %% the insertion of messages can be refactored to one method
	tryFlushMessages(SS,MsgCount).
	
handlePrivateMsg(S = #state{}, MsgCount,M = #eventMessage{}) ->
	SS = S#state{msgBuffer=insertMsg(M, S#state.msgBuffer)},  %% the insertion of messages can be refactored to one method
	tryFlushMessages(SS,MsgCount).
	
handleBroadcast(S = #state{}, MsgCount,M = #eventMessage{}) ->
	SS = S#state{msgBuffer=insertMsg(M, S#state.msgBuffer)},  %% the insertion of messages can be refactored to one method
	tryFlushMessages(SS,MsgCount).
	
handleUnfollow(S = #state{},M = #eventMessage{}) ->
	% We will not notify the client of this action, but we will 
	% remove from this worker's state the userId that made the unfollow,
	% so it's no longer on the follower list of this worker.
	case dict:is_key(M#eventMessage.fromUser, S#state.followers) of
		true ->	
			SS = S#state{followers=dict:erase(M#eventMessage.fromUser, S#state.followers)},
			SS;
		false ->
			S
	end.
	
handleFollow(S = #state{}, MsgCount,M = #eventMessage{}) -> 
	SS = S#state{msgBuffer=insertMsg(M, S#state.msgBuffer)},  %% the insertion of messages can be refactored to one method
	tryFlushMessages(SS,MsgCount).
	
handleFollow(S = #state{}, MsgCount,M = #eventMessage{},FollowerPid) ->
	SS = S#state{msgBuffer=insertMsg(M, S#state.msgBuffer)},
	SSS = SS#state{followers=dict:append(M#eventMessage.fromUser,FollowerPid,SS#state.followers)},
	tryFlushMessages(SSS, MsgCount).
	
tryFlushMessages(S = #state{}, MsgCount) ->
	OutboundMessages = lists:filter(fun(_A) -> _A#eventMessage.seq =< MsgCount end,S#state.msgBuffer),
		if length(OutboundMessages) > 0 -> 
				lists:foreach(fun(A) -> gen_tcp:send(S#state.clientSocket,A#eventMessage.payload) end,OutboundMessages),
				SS = S#state{msgBuffer=drop(length(OutboundMessages),S#state.msgBuffer)},
				SS;
			length(OutboundMessages) =:= 0 ->
				S
		end.
	
drop(N,L) when N =< 0 -> L;
drop(N,L) ->
	dropAcc(N,L,0).
	
dropAcc(_,[],_) -> [];
dropAcc(N, L = [_|T],Acc) ->
	if Acc < N ->
		dropAcc(N,T,Acc+1);
	   Acc =:= N ->
		L
	end.
	
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