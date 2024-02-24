import random

n = 500_000
print(n)
print(" ".join(str(random.randint(-2**31, 2**31-1)) for i in range(n)))
# print(" ".join(str(random.randint(-10**4, 10**4)) for i in range(n)))
