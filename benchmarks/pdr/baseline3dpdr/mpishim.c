#include <mpi.h>
__attribute__((constructor)) static void shim_mpi_init(void){
    int flag=0; MPI_Initialized(&flag);
    if(!flag){ int argc=0; char **argv=NULL; MPI_Init(&argc,&argv); }
}
