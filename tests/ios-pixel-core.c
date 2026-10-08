#include "../modules/long-image/ios/PixelCore.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
int main(int argc,char **argv) {
  if(argc!=4)return 2;
  char error[512]={0};int width=0,height=0;
  assert(LIImportPNG(argv[1],argv[2],&width,&height,error,sizeof(error))==1);
  size_t profileSize=0;uint8_t *profile=LICopyPNGProfile(argv[1],&profileSize);
  if(profile)assert(profileSize>0);
  LIFreeBuffer(profile);
  FILE *raw=fopen(argv[2],"rb");assert(raw);
  LIPngWriter *writer=LIWriterOpen(argv[1],argv[3],width,height,error,sizeof(error));assert(writer);
  unsigned char *row=malloc((size_t)width*4),*overlay=calloc((size_t)width,4);assert(row&&overlay);
  for(int y=0;y<height;y++){
    assert(fread(row,4,width,raw)==(size_t)width);
    /* A transparent overlay must preserve hidden RGB values, not just appearance. */
    LICompositeRGBA(row,overlay,width);assert(LIWriterRows(writer,row,1)==1);
  }
  assert(LIWriterFinish(writer)==1);LIWriterClose(writer);fclose(raw);
  unsigned char tile[4*3*2];assert(LIReadTile(argv[2],width,height,0,0,3,2,2,tile)==1);
  unsigned char base[]={12,23,34,0,100,120,140,255};
  unsigned char upper[]={0,0,0,0,255,0,0,255};
  LICompositeRGBA(base,upper,2);
  assert(base[0]==12&&base[1]==23&&base[2]==34&&base[3]==0);
  assert(base[4]==255&&base[5]==0&&base[6]==0&&base[7]==255);
  free(row);free(overlay);
  printf("PASS: iOS PNG import -> raw disk backing -> composite -> streaming PNG, %d x %d\n",width,height);
  return 0;
}
