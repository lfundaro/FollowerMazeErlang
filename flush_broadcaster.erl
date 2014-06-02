-module(flush_broadcaster).
-compile(export_all).

deliver_flush_signal(_,_,[]) -> ok; 
deliver_flush_signal(From,To,WorkerPidsList) ->
	lists:foreach(fun(Wp) -> Wp ! {try_delivery,From,To} end,WorkerPidsList).