#!/bin/bash

# Clone, build and install MAPL
# USAGE:
#   ./build_mapl.sh <MAPL_VERSION> <INSTALL_PREFIX>
#
#   DEFAULTS:
#    MAPL_VERSION   = v2.23.1
#    INSTALL_PREFIX = $PWD/INSTALL

set -eux

MAPL_VERSION=${1:-"v2.23.1"}
INSTALL_PREFIX=${2:-"$PWD/INSTALL"}

# Purge stale clone
[[ -d MAPL ]] && rm -rf MAPL

# Purge older install
[[ -d ${INSTALL_PREFIX} ]] && rm -rf ${INSTALL_PREFIX}

# clone repository and checkout specific version
git clone https://github.com/GEOS-ESM/MAPL
cd MAPL
git checkout ${MAPL_VERSION} 

# sanitize package as per NCO request
# Issue (1)
sed -i 's/http:\/\/gmao.gsfc.nasa.gov/DISABLED_BY_DEFAULT/g' gridcomps/History/MAPL_HistoryGridComp.F90
# Issue (2)
sed -i 's/http:\/\/gmao.gsfc.nasa.gov/DISABLED_BY_DEFAULT/g' base/MAPL_CFIO.F90
# Issue (3)
rm base/mapl_tree.py

# Verify that the changes were applied
git --no-pager diff


# Build and install

# 1. set compilers/stack version and load dependency modules

HPC_COMPILER=intel/2022.1.2
HPC_MPI=impi/2022.1.2

. ${MODULESHOME}/init/bash

# On Hera, please replace on WCOSS2
module use /scratch2/NCEPDEV/nwprod/hpc-stack/libs/hpc-stack/modulefiles/stack

module load hpc/1.1.0
module load hpc-${HPC_COMPILER}
module load hpc-${HPC_MPI}
module try-load cmake
module load esma_cmake
module load cmakemodules
module load ecbuild
export ECBUILD_ROOT=${ecbuild_ROOT}
module load gftl-shared
module load netcdf
module load esmf/8.3.0b09

module list

export FC=${MPI_FC}
export CC=${MPI_CC}
export CXX=${MPI_CXX}

# 2. build
[[ -d build ]] && rm -rf build
mkdir -p build && cd build

cmake .. \
      -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
      -DCMAKE_MODULE_PATH="${ESMA_CMAKE_ROOT};${CMAKEMODULES_ROOT}/Modules;${ECBUILD_ROOT}/share/ecbuild/cmake" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_WITH_FLAP=OFF \
      -DBUILD_WITH_PFLOGGER=OFF \
      -DESMA_USE_GFE_NAMESPACE=ON \
      -DBUILD_SHARED_MAPL=OFF \
      -DUSE_EXTDATA2G=OFF

# 3. install
make -j${NTHREADS:-4} install VERBOSE=1
