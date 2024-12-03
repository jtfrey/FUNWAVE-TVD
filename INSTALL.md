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


### Example build

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
[  3%] Building Fortran object src/CMakeFiles/funwave-intel-parallel-double-SPHERICAL.dir/mod_param.F.o
[  7%] Building Fortran object src/CMakeFiles/funwave-intel-parallel-double-SPHERICAL.dir/mod_global.F.o
[ 10%] Building Fortran object src/CMakeFiles/funwave-intel-parallel-double-SPHERICAL.dir/mod_dictionary.F.o
[ 14%] Building Fortran object src/CMakeFiles/funwave-intel-parallel-double-SPHERICAL.dir/mod_input.F.o
[ 17%] Building Fortran object src/CMakeFiles/funwave-intel-parallel-double-SPHERICAL.dir/mod_bathy_correction.F.o
[ 21%] Building Fortran object src/CMakeFiles/funwave-intel-parallel-double-SPHERICAL.dir/mod_parallel_field_io.F.o
[ 25%] Building Fortran object 
   :
[ 96%] Building Fortran object src/CMakeFiles/funwave-intel-parallel-double-SPHERICAL.dir/parallel.F.o
[100%] Linking Fortran executable funwave-intel-parallel-double-SPHERICAL
[100%] Built target funwave-intel-parallel-double-SPHERICAL
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

#define FUNWAVE_TVD_COMPILER "Intel"

#define ENABLE_COUPLING
/* #undef ENABLE_ZALPHA */
/* #undef ENABLE_MANNING */
/* #undef ENABLE_VESSEL */
/* #undef ENABLE_METEO */
/* #undef ENABLE_WIND */
#define ENABLE_SEDIMENT
/* #undef ENABLE_CHECK_MASS_CONSERVATION */
/* #undef ENABLE_TMP */
#define ENABLE_TRACKING
/* #undef ENABLE_FOAM */
/* #undef ENABLE_PRECIPITATION */
/* #undef ENABLE_SUBGRID */
/* #undef ENABLE_DEEP_DRAFT_VESSEL */
/* #undef ENABLE_FILTERING */
/* #undef ENABLE_ITERATION */
/* #undef ENABLE_AB_OUTPUT */
/* #undef ENABLE_SPHERICAL_IJ_STATION */
/* #undef ENABLE_UseEtaScreen */

/* #undef ENABLE_VESSEL_PANEL_SOURCE */
/* #undef ENABLE_REALISTIC_VESSEL_BODY */
/* #undef ENABLE_PROPELLER */

#define FUNWAVE_TVD_PRECISION "double"
#define ENABLE_DOUBLE_PRECISION

#define FUNWAVE_TVD_COORD_SYSTEM "spherical"
#define ENABLE_COORD_SPHERICAL

#define ENABLE_MPI
#define HAVE_INTEL_FORTRAN
/* #undef ENABLE_DEBUG */
#define ENABLE_SEDIMENT_DEBUG



#ifdef ENABLE_COUPLING
#   define COUPLING
#endif
#ifdef ENABLE_ZALPHA
#   define ZALPHA
#endif
#ifdef ENABLE_MANNING
#   define MANNING
#endif
#ifdef ENABLE_VESSEL
#   define VESSEL
#endif
#ifdef ENABLE_METEO
#   define METEO
#endif
#ifdef ENABLE_WIND
#   define WIND
#endif
#ifdef ENABLE_SEDIMENT
#   define SEDIMENT
#endif
#ifdef ENABLE_CHECK_MASS_CONSERVATION
#   define CHECK_MASS_CONSERVATION
#endif
#ifdef ENABLE_TMP
#   define TMP
#endif
#ifdef ENABLE_TRACKING
#   define TRACKING
#endif
#ifdef ENABLE_FOAM
#   define FOAM
#endif
#ifdef ENABLE_PRECIPITATION
#   define PRECIPITATION
#endif
#ifdef ENABLE_SUBGRID
#   define SUBGRID
#endif
#ifdef ENABLE_DEEP_DRAFT_VESSEL
#   define DEEP_DRAFT_VESSEL
#endif
#ifdef ENABLE_FILTERING
#   define FILTERING
#endif
#ifdef ENABLE_ITERATION
#   define ITERATION
#endif
#ifdef ENABLE_AB_OUTPUT
#   define AB_OUTPUT
#endif
#ifdef ENABLE_SPHERICAL_IJ_STATION
#   define SPHERICAL_IJ_STATION
#endif
#ifdef ENABLE_UseEtaScreen
#   define UseEtaScreen
#endif

#ifdef ENABLE_VESSEL_PANEL_SOURCE
#   define VESSEL_PANEL_SOURCE
#endif
#ifdef ENABLE_REALISTIC_VESSEL_BODY
#   define REALISTIC_VESSEL_BODY
#endif
#ifdef ENABLE_PROPELLER
#   define PROPELLER
#endif

#ifdef ENABLE_DOUBLE_PRECISION
#   define DOUBLE_PRECISION
#endif
#ifndef ENABLE_COORD_SPHERICAL
#   define CARTESIAN
#endif
#ifdef ENABLE_MPI
#   define PARALLEL
#endif
#ifdef HAVE_INTEL_FORTRAN
#   define INTEL
#endif
#ifdef ENABLE_DEBUG
#   define DEBUG
#endif
#ifdef ENABLE_SEDIMENT_DEBUG
#   define SEDIMENT_DEBUG
#endif

#endif /* __FUNWAVE_TVD_CONFIG_H__ */
```

If the `make install` command is used to install the software after build, the `funwave-tvd-config.h` file will be installed in the `${CMAKE_INSTALL_PREFIX}/include` path.