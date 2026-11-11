# Links the native tests with the address and undefined behaviour sanitizers, so an
# out of bounds read or similar fails the test run instead of going unnoticed.
Import("env")
env.Append(LINKFLAGS=["-fsanitize=address,undefined"])
