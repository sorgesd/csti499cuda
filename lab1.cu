#include <stdio.h>
#include <iostream>
#include <fstream>
#include <iterator>

#include <curand.h>
#include <curand_kernel.h>

#define N 10
#define CHARS_PER_PASSWORD 30
#define M 11000
#define THREADS_PER_BLOCK 512
using namespace std;

__device__ char* findPassword(char *grid, int x, int n);
__device__ char* generatePassword(char *grid, char* domain, int domainSize);
__device__ int randomNumber(int blockId);
__device__ int findCharIndex(char *grid, char toFind, int fromX, int fromY, int dir, int n);
__device__ int index(int x, int y, int n);

__global__ void findPasswords( char *grid, char *result, int n) {
	int index = blockIdx.x * blockDim.x + threadIdx.x;
	if (index < M) {
		char* arr = findPassword(grid, index, n);
		for (int i = 0; i < CHARS_PER_PASSWORD; i++) {
			result[(index * CHARS_PER_PASSWORD) + i] = arr[i];
		}
	}
}

__device__ char* findPassword(char *grid, int x, int n) {
	char * thisArr = new char[CHARS_PER_PASSWORD]();
	char domain[3];
	domain[0] = 'A';
	domain[1] = 'B';
	domain[2] = 'C';

	int domainSize = (sizeof(domain)/sizeof(char));
	char * generatedPassword = generatePassword(grid, domain, domainSize);

	int rand1 = randomNumber(x) % n;
	char random1 = '0' + rand1;
	
	for (int i = 0; i < domainSize; i++) {
		thisArr[i] = domain[i];
	}

	thisArr[domainSize] = '-';
	thisArr[domainSize + 1] = '>';

	for (int i = 0; i < domainSize * 2; i++) {
		thisArr[domainSize + 2 + i] = generatedPassword[i];
	}

	return thisArr;
}


__device__ char* generatePassword(char *grid, char* domain, int domainSize) {
	char* generatedPassword = new char[domainSize*2]();

	int n = 6;

	int x = 0;
	int y = 0;
	int dir = 0;

	for (int i = 0; i < domainSize; i++) {
		int charIndext = findCharIndex(grid, domain[i], x, y, dir, n);
		if (dir % 2 == 0) {
			x = charIndext;
		} else {
			y = charIndext;
		}
		dir++;
	}

	for (int i = 0; i < domainSize; i++) {
			int charIndex = findCharIndex(grid, domain[i], x, y, dir, n);
			int nextOne;
			int nextTwo;
			int nextThree;

			if ( dir % 2 == 0) {
				if (charIndex < x) {
					nextOne = charIndex - 1;
					nextTwo = charIndex - 2;
					nextThree = charIndex - 3;	
				} else {
					nextOne = charIndex + 1;
					nextTwo = charIndex + 2;
					nextThree = charIndex + 3;
				}
			} else {
				if (charIndex < y) {
					nextOne = charIndex - 1;
                                        nextTwo = charIndex - 2;
					nextThree = charIndex - 3;
				} else {
					nextOne = charIndex + 1;
                                        nextTwo = charIndex + 2;
					nextThree = charIndex + 3;
				}
			}

			if (nextOne >= n) {
				nextOne = nextOne - n;
			} else if (nextOne < 0) {
				nextOne = n + nextOne;
			}
			
			if (nextTwo >= n) {
                                nextTwo = nextTwo - n;
                        } else if (nextTwo < 0) {
                                nextTwo = n + nextTwo;
                        }

			if (nextThree >= n) {
                                nextThree = nextThree - n;
                        } else if (nextThree < 0) {
                                nextThree = n + nextThree;
                        }


			if (dir % 2 == 0) {
				if (i < domainSize - 1 && grid[index(nextTwo,y,n)] == domain[i + 1]) {
					x = nextThree;
				} else {
					x = nextTwo;
				}
				generatedPassword[i*2] = grid[index(nextOne, y, n)];
                		generatedPassword[(i*2) + 1] = grid[index(nextTwo,y,n)];
			} else {
				if (i < domainSize - 1 && grid[index(x,nextTwo,n)] == domain[i + 1]) {
					y = nextThree;
				} else {
					y = nextTwo;
				}
				generatedPassword[i*2] = grid[index(x,nextOne,n)];
                		generatedPassword[(i*2) + 1] = grid[index(x,nextTwo,n)];
			} 
			
		dir++;
	}
	
	return generatedPassword;
}

__device__ int findCharIndex(char *grid, char toFind, int fromX, int fromY, int dir, int n) {
	if (dir % 2 == 0) {
		for (int i = 0; i < n; i++) {
			if (grid[index(i,fromY,n)] == toFind) {
				return i;
			}
		}
	} else {
		for (int i = 0; i < n; i++) {
			if (grid[index(fromX, i, n)] == toFind) {
				return	i;
			}
		}
	}
	return 0;
}

__device__ int randomNumber(int blockId) {
	curandState_t state;
	curand_init(clock64(), blockId, 0, &state);
	return curand(&state);
}

__device__ int index(int x, int y, int n) {
	return n*y + x;
}

int main( void ) 
{
	int n;
	cout << "What is N?\n";
	cin >> n;
	cout << "n set to " + n; 
	
	ifstream mygridfile;
	mygridfile.open("grid.txt");
	
	char* grid;
	cudaMallocManaged( (void**)&grid, n * n * sizeof(char));
	for (int i = 0; i < (n*n); i++) {
		mygridfile >> grid[i];
	}

	mygridfile.close();

	cout << "print here";
	for (int i = 0; i < n*n; i++) {
		cout << grid[i];
	}

	char* result;
	cudaMallocManaged( (void**)&result, CHARS_PER_PASSWORD*sizeof(char)*M);
	findPasswords<<<M/THREADS_PER_BLOCK,THREADS_PER_BLOCK>>>(grid, result, n);
	cudaDeviceSynchronize();

	ofstream resultfile;
	resultfile.open("passwords.txt");
	cout << "test \n";
	for( int i = 0 ; i < M*CHARS_PER_PASSWORD; i ++ ){
		//cout << i;
		//cout << " : ";
		if (result[i]!='\0') { 
			resultfile << result[i];
		}
		if ((i + 1) % 30 == 0) {
			resultfile << endl;
		} 
	}
	cout << endl;
	resultfile.close();

	return 0;
}
