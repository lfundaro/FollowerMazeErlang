## Requirements:

This challenged has been programmed on Erlang. So you need to install the Erlang VM: 

For Ubuntu:
```
$> sudo apt-get install erlang
```

Mac:

 Homebrew:
 ```
		$> brew install erlang
```

 MacPorts:
 ```
		$> port install erlang
```
		
## Build:

Go to the base directory and do:
```
$> erl -make
```

This will compile all the sources under the src/ directory and put all 
the bytecode files (*.beam) under ebin/. 

## Running 

Once compiled, within  the base directory do:
```
$> erl -pa ebin/
```
to start an Erlang VM. Then inside the Erlang console:
```
$> make:all([load]).
```
To run the tests:
```
$> eunit:test(utils_tests).
$> eunit:test(counter_worker_tests).
```
Finally to run do:
```
$> P = follower_maze:init().
```
This will start the program and will return a process Pid, that you could use later to 
shutdown the application.

## Shutdown the application 

Within the Erlang VM console where you ran the program, do: 
```
$> exit(P, shutdown).
```
where P is the value returned by follower_maze:init() when running.

## TODO

* More tests, specially tests that will cover process handling. 
  Need to test proper creating and shutdown. 
* Leverage the building system. We are using a very basic way 
  of building an Erlang project. Normally, we would need to 
  use the OTP standards, which consists on making a *.app file 
  under ebin/ and possibly using a better building tool like 
  rebar. 
* Again, this is a simple but effective implementation of what you 
  could do with the actor model. Nonetheless, there are more profound 
  concepts that should be used on this application to make it "Erlang 
  reliable style", that is, making effective use of monitors, supervisors, 
  etc. All those I decided to leave out for simplicity. Besides that, 
  I had to learn Erlang from zero to code this challenge, so putting 
  those features was out of the scope. 

