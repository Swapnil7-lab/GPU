/*
	CS 6023 Assignment 3.
	Do not make any changes to the boiler plate code or the other files in the folder.
	Use cudaFree to deallocate any memory not in usage.
	Optimize as much as possible.
 */

#include "SceneNode.h"
#include <queue>
#include "Renderer.h"
#include <stdio.h>
#include <string.h>
#include <cuda.h>
#include <chrono>

__global__
void dCreateFinalScene(int *dFinalPng, int *dOpacityMap, int *dOpacity, int* dMesh,
    int *dGlobalCoordinatesX, int *dGlobalCoordinatesY, int *dFrameSizeX,
    int *dFrameSizeY, long int* d_translations_final, int *globalFrameSizeX, int *globalFrameSizeY, int *tid){
      printf("tid: %d\n", *tid);
      printf("%d\n", *dGlobalCoordinatesX);
      printf("%d\n", *dGlobalCoordinatesY);
      printf("%ld\n", *(d_translations_final+ (*tid) * 4 + 0));
      printf("%ld\n", *(d_translations_final+ (*tid) * 4 + 1));
      printf("%ld\n", *(d_translations_final+ (*tid) * 4 + 2));
      printf("%ld\n", *(d_translations_final+ (*tid) * 4 + 3));

      (*dGlobalCoordinatesX) -= *(d_translations_final+ (*tid) * 4 + 0);//up
      (*dGlobalCoordinatesX) += *(d_translations_final+ (*tid) * 4 + 1);//down
      (*dGlobalCoordinatesY) -= *(d_translations_final+ (*tid) * 4 + 2);//left
      (*dGlobalCoordinatesY) += *(d_translations_final+ (*tid) * 4 + 3);//right


      printf("%d\n", *dFrameSizeX);
      printf("%d\n", *dFrameSizeY);
      printf("%d\n", *dGlobalCoordinatesX);
      printf("%d\n", *dGlobalCoordinatesY);
      printf("%d\n", *globalFrameSizeX);
      printf("%d\n", *globalFrameSizeY);


      for(int i = 0; i < (*dFrameSizeX); i++){
        for(int j = 0; j < (*dFrameSizeY); j++){
          if((*dGlobalCoordinatesX) + i >= 0 && (*dGlobalCoordinatesX) + i < (*globalFrameSizeX)){
            if((*dGlobalCoordinatesY) + j >= 0 && (*dGlobalCoordinatesY) + j < (*globalFrameSizeY)){
              if(*(dOpacityMap + ((*dGlobalCoordinatesX) + i) * (*globalFrameSizeY) + (*dGlobalCoordinatesY) + j) < (*dOpacity)){
                *(dOpacityMap + ((*dGlobalCoordinatesX) + i) * (*globalFrameSizeY) + (*dGlobalCoordinatesY) + j) = (*dOpacity);
                *(dFinalPng + ((*dGlobalCoordinatesX) + i) * (*globalFrameSizeY) +  (*dGlobalCoordinatesY) + j) =
                *(dMesh + (i * (*dFrameSizeY)) + j);
              }
            }

          }
        }
      }
    }

__global__
void dcalcTranslations(int* dParent, long int* dTranslations_final, int *V, int *done){
  int tid = blockIdx.x * blockDim.x + threadIdx.x;


  if(tid < *V){
    printf("tid: %d\n", tid);

    while(done[tid] == 0){
      if(done[dParent[tid]] == 1){
        printf("parent of %d id %d", tid, dParent[tid]);
        *(dTranslations_final + (tid * 4) + 0) += *(dTranslations_final + (dParent[tid] * 4) + 0);
        *(dTranslations_final + (tid * 4) + 1) += *(dTranslations_final + (dParent[tid] * 4) + 1);
        *(dTranslations_final + (tid * 4) + 2) += *(dTranslations_final + (dParent[tid] * 4) + 2);
        *(dTranslations_final + (tid * 4) + 3) += *(dTranslations_final + (dParent[tid] * 4) + 3);
        
        done[tid] = 1;
      }
    }
  }
}


void readFile (const char *fileName, std::vector<SceneNode*> &scenes, std::vector<std::vector<int> > &edges, std::vector<std::vector<int> > &translations, int &frameSizeX, int &frameSizeY) {
	/* Function for parsing input file*/

	FILE *inputFile = NULL;
	// Read the file for input.
	if ((inputFile = fopen (fileName, "r")) == NULL) {
		printf ("Failed at opening the file %s\n", fileName) ;
		return ;
	}

	// Input the header information.
	int numMeshes ;
	fscanf (inputFile, "%d", &numMeshes) ;
	fscanf (inputFile, "%d %d", &frameSizeX, &frameSizeY) ;


	// Input all meshes and store them inside a vector.
	int meshX, meshY ;
	int globalPositionX, globalPositionY; // top left corner of the matrix.
	int opacity ;
	int* currMesh ;
	for (int i=0; i<numMeshes; i++) {
		fscanf (inputFile, "%d %d", &meshX, &meshY) ;
		fscanf (inputFile, "%d %d", &globalPositionX, &globalPositionY) ;
		fscanf (inputFile, "%d", &opacity) ;
		currMesh = (int*) malloc (sizeof (int) * meshX * meshY) ;
		for (int j=0; j<meshX; j++) {
			for (int k=0; k<meshY; k++) {
				fscanf (inputFile, "%d", &currMesh[j*meshY+k]) ;
			}
		}
		//Create a Scene out of the mesh.
		SceneNode* scene = new SceneNode (i, currMesh, meshX, meshY, globalPositionX, globalPositionY, opacity) ;
		scenes.push_back (scene) ;
	}

	// Input all relations and store them in edges.
	int relations;
	fscanf (inputFile, "%d", &relations) ;
	int u, v ;
	for (int i=0; i<relations; i++) {
		fscanf (inputFile, "%d %d", &u, &v) ;
		edges.push_back ({u,v}) ;
	}

	// Input all translations.
	int numTranslations ;
	fscanf (inputFile, "%d", &numTranslations) ;
	std::vector<int> command (3, 0) ;
	for (int i=0; i<numTranslations; i++) {
		fscanf (inputFile, "%d %d %d", &command[0], &command[1], &command[2]) ;
		translations.push_back (command) ;
	}
}


void writeFile (const char* outputFileName, int *hFinalPng, int frameSizeX, int frameSizeY) {
	/* Function for writing the final png into a file.*/
	FILE *outputFile = NULL;
	if ((outputFile = fopen (outputFileName, "w")) == NULL) {
		printf ("Failed while opening output file\n") ;
	}

	for (int i=0; i<frameSizeX; i++) {
		for (int j=0; j<frameSizeY; j++) {
			fprintf (outputFile, "%d ", hFinalPng[i*frameSizeY+j]) ;
		}
		fprintf (outputFile, "\n") ;
	}
}


int main (int argc, char **argv) {

	// Read the scenes into memory from File.
	const char *inputFileName = argv[1] ;
	int* hFinalPng ;

	int frameSizeX, frameSizeY ;
	std::vector<SceneNode*> scenes ;
	std::vector<std::vector<int> > edges ;
	std::vector<std::vector<int> > translations ;
	readFile (inputFileName, scenes, edges, translations, frameSizeX, frameSizeY) ;
	hFinalPng = (int*) malloc (sizeof (int) * frameSizeX * frameSizeY) ;

	// Make the scene graph from the matrices.
    Renderer* scene = new Renderer(scenes, edges) ;

	// Basic information.
	int V = scenes.size () ;
	int E = edges.size () ;
	int numTranslations = translations.size () ;

	// Convert the scene graph into a csr.
	scene->make_csr () ; // Returns the Compressed Sparse Row representation for the graph.
	int *hOffset = scene->get_h_offset () ;
	int *hCsr = scene->get_h_csr () ;
	int *hOpacity = scene->get_opacity () ; // hOpacity[vertexNumber] contains opacity of vertex vertexNumber.
	int **hMesh = scene->get_mesh_csr () ; // hMesh[vertexNumber] contains the mesh attached to vertex vertexNumber.
	int *hGlobalCoordinatesX = scene->getGlobalCoordinatesX () ; // hGlobalCoordinatesX[vertexNumber] contains the X coordinate of the vertex vertexNumber.
	int *hGlobalCoordinatesY = scene->getGlobalCoordinatesY () ; // hGlobalCoordinatesY[vertexNumber] contains the Y coordinate of the vertex vertexNumber.
	int *hFrameSizeX = scene->getFrameSizeX () ; // hFrameSizeX[vertexNumber] contains the vertical size of the mesh attached to vertex vertexNumber.
	int *hFrameSizeY = scene->getFrameSizeY () ; // hFrameSizeY[vertexNumber] contains the horizontal size of the mesh attached to vertex vertexNumber.

	auto start = std::chrono::high_resolution_clock::now () ;


	// Code begins here.
	// Do not change anything above this comment.
  int h_parent[V];
  int h_done[V];
  h_parent[0] = 0;

  for(int i = 0; i < edges.size(); i++){
    h_parent[edges[i][1]] = edges[i][0];
  }
  for(int i = 0; i < V; i++){
    h_done[i] = 0;
  }
  h_done[0] = 1;

  long int h_translations_final[V*4] = {0};

  for(int i = 0; i < translations.size(); i++){//1 2 4
    std::vector<int> translation = translations[i];
    h_translations_final[translation[0] * 4 + translation[1]] += translation[2];
  }

  int *dParent;
  long int *dTranslations_final;
  int *total_nodes;
  int* d_done;
  int *dFinalPng;
  int *dOpacityMap;

  cudaMalloc(&dParent, (V) * sizeof(int));
  cudaMalloc(&dTranslations_final, (V * 4) * sizeof(long int));
  cudaMalloc(&total_nodes, sizeof(int));
  cudaMalloc(&d_done, V * sizeof(int));
  cudaMalloc(&dFinalPng, sizeof (int) * frameSizeX * frameSizeY);
  cudaMalloc(&dOpacityMap, sizeof (int) * frameSizeX * frameSizeY);

  cudaMemcpy(dParent, h_parent, V * sizeof(int),cudaMemcpyHostToDevice);
  cudaMemcpy(dTranslations_final, h_translations_final, (4 * V) * sizeof(long int),cudaMemcpyHostToDevice);
  cudaMemcpy(total_nodes, &V, sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_done,h_done,V * sizeof(int),cudaMemcpyHostToDevice);
  cudaMemset(dOpacityMap, INT_MIN, (frameSizeX * frameSizeY) * sizeof(int));
  cudaMemset(dFinalPng, 0, (frameSizeX * frameSizeY) * sizeof(int));
  //transitions
  dcalcTranslations<<<ceil(V/1024.0), 1024>>>(dParent, dTranslations_final, total_nodes, d_done);
  cudaDeviceSynchronize();
  cudaMemcpy(h_translations_final, dTranslations_final, (4 * V) * sizeof(long int), cudaMemcpyDeviceToHost);

  for(int i = 0; i < V; i++)
  printf("%ld %ld %ld %ld\n", *(h_translations_final + (i * 4) + 0), *(h_translations_final + (i * 4) + 1), *(h_translations_final + (i * 4) + 2), *(h_translations_final + (i * 4) + 3));

  //scene
  for(int i = 0; i < V; i++){
    int *dOpacity;
    int *dMesh;
    int *dGlobalCoordinatesX;
    int *dGlobalCoordinatesY;
    int *dFrameSizeX;
    int *dFrameSizeY;
    int *globalFrameSizeX;
    int *globalFrameSizeY;
    int *tid;

    cudaMalloc(&tid, sizeof(int));
    cudaMalloc(&globalFrameSizeX, sizeof(int));
    cudaMalloc(&globalFrameSizeY, sizeof(int));
    cudaMalloc(&dOpacity, sizeof(int));
    cudaMalloc(&dGlobalCoordinatesX, sizeof(int));
    cudaMalloc(&dGlobalCoordinatesY, sizeof(int));
    cudaMalloc(&dFrameSizeX, sizeof(int));
    cudaMalloc(&dFrameSizeY, sizeof(int));
    cudaMalloc(&dMesh, (hFrameSizeX[i] * hFrameSizeY[i]) * sizeof(int));

    cudaMemcpy(dOpacity, &hOpacity[i], sizeof(int) ,cudaMemcpyHostToDevice);
    cudaMemcpy(dGlobalCoordinatesX, &hGlobalCoordinatesX[i], sizeof(int) ,cudaMemcpyHostToDevice);
    cudaMemcpy(dGlobalCoordinatesY, &hGlobalCoordinatesY[i], sizeof(int) ,cudaMemcpyHostToDevice);
    cudaMemcpy(dFrameSizeX, &hFrameSizeX[i], sizeof(int) ,cudaMemcpyHostToDevice);
    cudaMemcpy(dFrameSizeY, &hFrameSizeY[i], sizeof(int) ,cudaMemcpyHostToDevice);
    cudaMemcpy(dMesh, hMesh[i], (hFrameSizeX[i] * hFrameSizeY[i]) * sizeof(int) ,cudaMemcpyHostToDevice);
    cudaMemcpy(tid, &i, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(globalFrameSizeX, &frameSizeX, sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpy(globalFrameSizeY, &frameSizeY, sizeof(int), cudaMemcpyHostToDevice);


    dCreateFinalScene<<<1,1>>>(dFinalPng, dOpacityMap, dOpacity, dMesh,
    dGlobalCoordinatesX, dGlobalCoordinatesY, dFrameSizeX,
    dFrameSizeY, dTranslations_final, globalFrameSizeX, globalFrameSizeY, tid);
    cudaDeviceSynchronize();
  }

  cudaMemcpy(hFinalPng, dFinalPng, (frameSizeX * frameSizeY) * sizeof(int),cudaMemcpyDeviceToHost);

	// Do not change anything below this comment.
	// Code ends here.

	auto end  = std::chrono::high_resolution_clock::now () ;

	std::chrono::duration<double, std::micro> timeTaken = end-start;

	printf ("execution time : %f\n", timeTaken.count()) ;
	// Write output matrix to file.
	const char *outputFileName = argv[2] ;
	writeFile (outputFileName, hFinalPng, frameSizeX, frameSizeY) ;

}
