# Installing FUNWAVE-TVD

The source package currently includes two build systems:

1. The traditional system using a collection of static `make` files
2. A CMake build description

## Traditional make

To use the traditional static `make` files, the top-level [Makefile](./Makefile) should be edited.    A series of variables defined at the top of the file should be modified as necessary:  e.g. the compiler is chosen via the value of the `COMPILER` variable.

### Build

Once the top-level [Makefile](./Makefile) has been edited, the build is effected using the `make` command in the source directory:

```
$ make
```

## CMake

The CMake build system is controlled by the selection of Fortran compiler and a set of variables that can be specified on the command line or via the interactive `ccmake` interface.

### Compiler and base options

The Fortran compiler should be selected by setting the `FC` variable in the environment prior to invoking a `cmake` or `ccmake` command.  For example, if the classic Intel Fortran compiler `ifort` is present in the shell environment (where the ellipsis represents additional arguments):

```
$ FC=ifort cmake …
```

By comparison, the GNU Fortran compiler would be chosen using

```
$ FC=gfortran cmake …
```

Standard CMake variables that should be used include:

| Variable | Discussion |
| :--- | :--- |
| `CMAKE_BUILD_TYPE` | The standard build types:  **Release**, Debug, RelWithDebInfo, or MinSizeRel |
| `CMAKE_INSTALL_PREFIX` | The base path into which products will be installed (e.g. in the `bin` subdirectory) |

The final executable will by default be named `funwave`.  The original `make` system generated an executable name that contained all of the optional features separated by dashes, e.g. `funwave-COUPLING-ZALPHA-WIND-SEDIMENT-PRECIPITATION`.  This behavior can be requested by enabling the `ENABLE_GENERATED_EXENAME` flag, e.g. adding `-DENABLE_GENERATED_EXENAME=On` to your `cmake` command line.

#### Intel compiler

If an Intel compiler is chosen and the `CMAKE_BUILD_TYPE` is not `Debug`, then extensive interprocedural optimizations can be requested using the `ENABLE_INTEL_IPO` variable:

```
$ FC=ifort cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_INTEL_IPO=On …
```

### Optional features

Most FUNWAVE-TVD optional features are enabled by means of boolean variables:

| Variable | Discussion |
| :--- | :--- |
| `ENABLE_MPI` | Compile the PARALLEL variant of the code; requires an MPI compiler to be present in the shell environment |
| `ENABLE_COUPLING` | *Add more information here…* |
| `ENABLE_ZALPHA` | *Add more information here…* |
| `ENABLE_MANNING` | *Add more information here…* |
| `ENABLE_VESSEL` | *Add more information here…* |
| `ENABLE_METEO` | *Add more information here…* |
| `ENABLE_WIND` | *Add more information here…* |
| `ENABLE_SEDIMENT` | *Add more information here…* |
| `ENABLE_CHECK_MASS_CONSERVATION` | *Add more information here…* |
| `ENABLE_TMP` | *Add more information here…* |
| `ENABLE_TRACKING` | *Add more information here…* |
| `ENABLE_FOAM` | *Add more information here…* |
| `ENABLE_PRECIPITATION` | *Add more information here…* |
| `ENABLE_SUBGRID` | *Add more information here…* |
| `ENABLE_DEEP_DRAFT_VESSEL` | *Add more information here…* |
| `ENABLE_FILTERING` | *Add more information here…* |
| `ENABLE_ITERATION` | *Add more information here…* |
| `ENABLE_AB_OUTPUT` | *Add more information here…* |
| `ENABLE_SPHERICAL_IJ_STATION` | *Add more information here…* |
| `ENABLE_UseEtaScreen` | *Add more information here…* |

Boolean variables are set from the command line using arguments following the format `-D<VARIABLE-NAME>=(On|Off)`.

The floating-point precision is controlled by the `FP_PRECISION` variable which can adopt the values `single` or `double`.  The default is `double`.

The program can use spherical or Cartesian coordinates.  This behavior is controlled by the `COORD_SYSTEM` variable which can adopt the values `spherical` or `cartesian`.  The default is `spherical`.

### SEDIMENT

If the `CMAKE_BUILD_TYPE` is `Debug` and the SEDIMENT feature is enabled, additional debugging output can be suppressed in the sediment module by setting the `ENABLE_SEDIMENT_DEBUG` variable to false.  The variable defaults to true:

```
$ FC=ifort cmake -DCMAKE_BUILD_TYPE=Debug -DENABLE_SEDIMENT_DEBUG=Off …
```

### VESSEL

The `ENABLE_VESSEL` option, when true, makes three additional optional features available:

| Variable | Discussion |
| :--- | :--- |
| `ENABLE_VESSEL_PANEL_SOURCE` | *Add more information here…* |
| `ENABLE_REALISTIC_VESSEL_BODY` | *Add more information here…* |
| `ENABLE_PROPELLER` | *Add more information here…* |


### Example build #1

The following build will make use of an MPI compiler (`mpifort`) that was added to the environment and all default optional features.  An optimized (`Release`) build will be performed with Intel IPO enabled.

```
$ vpkg_require cmake/3.28.3 openmpi/4.1.4:intel-2020
Adding package `cmake/3.28.3` to your environment
Adding dependency `libfabric/1.13.2` to your environment
Adding dependency `intel/2020u4` to your environment
Adding package `openmpi/4.1.4:intel-2020` to your environment

$ mkdir build-intel-openmpi
$ cd build-intel-openmpi

$ FC=mpifort cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_MPI=On -DENABLE_INTEL_IPO=On ..
-- The Fortran compiler identification is Intel 19.1.3.20200925
-- Detecting Fortran compiler ABI info
-- Detecting Fortran compiler ABI info - done
-- Check for working Fortran compiler: /opt/shared/openmpi/4.1.4-intel-2020/bin/mpifort - skipped
-- Found MPI_Fortran: /opt/shared/openmpi/4.1.4-intel-2020/bin/mpifort (found version "3.1") 
-- Found MPI: TRUE (found version "3.1")  
-- Configuring done (3.8s)
-- Generating done (0.0s)
-- Build files have been written to: /home/1001/FUNWAVE-TVD/build-intel-openmpi

$ make
[  3%] Building Fortran object src/CMakeFiles/funwave.dir/mod_param.F.o
[  7%] Building Fortran object src/CMakeFiles/funwavedir/mod_global.F.o
[ 10%] Building Fortran object src/CMakeFiles/funwave.dir/mod_dictionary.F.o
[ 14%] Building Fortran object src/CMakeFiles/funwave.dir/mod_input.F.o
[ 17%] Building Fortran object src/CMakeFiles/funwave.dir/mod_bathy_correction.F.o
[ 21%] Building Fortran object src/CMakeFiles/funwave.dir/mod_parallel_field_io.F.o
[ 25%] Building Fortran object 
   :
[ 96%] Building Fortran object src/CMakeFiles/funwave.dir/parallel.F.o
[100%] Linking Fortran executable funwave
[100%] Built target funwave
```

#### Build options header

As part of the CMake configuration process a header file is generated that encapsulates all of the build options, selected compiler, and FUNWAVE-TVD version information.  Code (FUNWAVE-TVD itself or external, third-party applications) can `#include` this header file rather than reproducing all of the compiler command-line options.  For example, in the build directory above:

```
$ cat funwave-tvd-config.h 

#ifndef __FUNWAVE_TVD_CONFIG_H__
#define __FUNWAVE_TVD_CONFIG_H__

#define FUNWAVE_TVD_VERSION_STRING "3.4.0"
#define FUNWAVE_TVD_VERSION_MAJOR 3
#define FUNWAVE_TVD_VERSION_MINOR 4
#define FUNWAVE_TVD_VERSION_PATCH 0

#include "funwave-tvd-githash.h"

#define FUNWAVE_TVD_COMPILER_STRING "Intel"

#define FUNWAVE_TVD_FEATURES_STRING "double+MPI+spherical"

#define ENABLE_COUPLING
/* #undef ENABLE_ZALPHA */
/* #undef ENABLE_MANNING */

   :
   
#if defined(ENABLE_DEBUG) && ! defined(DEBUG)
#   define DEBUG
#endif
#if defined(ENABLE_SEDIMENT_DEBUG) && ! defined(SEDIMENT_DEBUG)
#   define SEDIMENT_DEBUG
#endif

#endif /* __FUNWAVE_TVD_CONFIG_H__ */
```

If the `make install` command is used to install the software after build, the `funwave-tvd-config.h` file will be installed in the `${CMAKE_INSTALL_PREFIX}/include` path.

### Example build #2

The code can be compiled without MPI parallelism by not setting the `ENABLE_MPI` flag.  CMake is also good at establishing dependency rules that allow for efficient (and correctly-ordered) parallel builds:

```
$ vpkg_require cmake/3.28.3 intel-oneapi/2023
Adding package `cmake/3.28.3` to your environment
Adding dependency `binutils/2.35` to your environment
Adding dependency `gcc/12.1.0` to your environment
Adding package `intel-oneapi/2023.0.0.25537` to your environment

$ mkdir build-intel-oneapi
$ cd build-intel-oneapi

$ FC=ifx cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_INTEL_IPO=On ..
-- The Fortran compiler identification is IntelLLVM 2023.0.0
-- Detecting Fortran compiler ABI info
-- Detecting Fortran compiler ABI info - done
-- Check for working Fortran compiler: /opt/shared/intel-oneapi/2023.0.0.25537/compiler/2023.0.0/linux/bin/ifx - skipped
-- Configuring done (0.9s)
-- Generating done (0.0s)
-- Build files have been written to: /home/1001/FUNWAVE-TVD/build-intel-oneapi


$ make clean ; time make
   :
[ 96%] Building Fortran object src/CMakeFiles/funwave.dir/samples.F.o
[100%] Linking Fortran executable funwave
[100%] Built target funwave

real    0m30.161s
user    0m26.665s
sys     0m3.212s


$ make clean ; time make -j 4
   :
[ 96%] Building Fortran object src/CMakeFiles/funwave.dir/main.F.o
[100%] Linking Fortran executable funwave
[100%] Built target funwave

real    0m21.983s
user    0m25.624s
sys     0m2.794s
```

The executable produced can be run; lacking input files the output is relatively short:

```
$ ./src/funwave
................................................................
 
  F U N W A V E - T V D
  v3.4.0
  (git hash bf6662da831553ace358a1f23ab8578ae0c2c124,
     origin https://github.com/jtfrey/FUNWAVE-TVD.git)
 
       Compiler: IntelLLVM
        FP mode: double-precision
      Coord sys: spherical
 
................................................................
 
 TITLE DOES NOT EXIST. USE DEFAULT VALUE
 Mglob DOES NOT EXIST. USE DEFAULT VALUE
                                  Mglob:                       NOT DEFINED, STOP
```

Enabling sediment and precipitation, rebuilding, and rerunning:

```
$ FC=ifx cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_INTEL_IPO=On -DENABLE_SEDIMENT=On -DENABLE_PRECIPITATION=On ..
$ make -j 4
$ ./src/funwave 
................................................................
 
  F U N W A V E - T V D
  v3.4.0
  (git hash bf6662da831553ace358a1f23ab8578ae0c2c124,
     origin https://github.com/jtfrey/FUNWAVE-TVD.git)
 
       Compiler: IntelLLVM
        FP mode: double-precision
      Coord sys: spherical
       Features: PRECIPITATION
                 SEDIMENT
 
................................................................
 
 TITLE DOES NOT EXIST. USE DEFAULT VALUE
 Mglob DOES NOT EXIST. USE DEFAULT VALUE
                                  Mglob:                       NOT DEFINED, STOP
```

Under the CMake build system, a header that summarizes the version, compiler, and features is written to stdout as the program starts.  Jobs run with this executable will thus very clearly indicate the source and options from which they derive.

