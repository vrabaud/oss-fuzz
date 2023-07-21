#!/bin/bash -eu
# Copyright 2018 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

build_dir=$WORK/build-$SANITIZER
install_dir=$WORK/install-$SANITIZER

compile_fuzztests.sh

#rm -fr $build_dir
mkdir -p $build_dir
pushd $build_dir
# Force static because absl does not compile otherwise.
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$install_dir \
  -DBUILD_SHARED_LIBS=OFF -DOPENCV_GENERATE_PKGCONFIG=OFF \
  -DBUILD_TESTS=ON -DBUILD_FUZZ_TESTS=ON -DBUILD_PERF_TESTS=OFF \
  -DBUILD_opencv_apps=OFF $SRC/opencv
#  -DCMAKE_C_COMPILER="${CC}" -DCMAKE_CXX_COMPILER="${CXX}" \
#  -DCMAKE_C_FLAGS="${CFLAGS}" \
#  -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
#  -DCMAKE_EXE_LINKER_FLAGS="${CXXFLAGS}" \
#  -DCMAKE_MODULE_LINKER_FLAGS="${CXXFLAGS}" \
#  -DCMAKE_SHARED_LINKER_FLAGS="${CXXFLAGS}" \
#  -DCMAKE_STATIC_LINKER_FLAGS="${CXXFLAGS}" $SRC/opencv
make -j $(nproc) opencv_fuzz_tests
# The following is taken from https://github.com/google/oss-fuzz/blob/31ac7244748ea7390015455fb034b1f4eda039d9/infra/base-images/base-builder/compile_fuzztests.sh#L59
# Iterate the fuzz binaries and list each fuzz entrypoint in the binary. For
# each entrypoint create a wrapper script that calls into the binaries the
# given entrypoint as argument.
# The scripts will be named:
# {binary_name}@{fuzztest_entrypoint}
FUZZ_TEST_BINARIES_OUT_PATHS=`ls ./bin/opencv_fuzz_*`
#cp ./bin/opencv_fuzz_* $OUT/
echo "Fuzz binaries: $FUZZ_TEST_BINARIES_OUT_PATHS"
for fuzz_main_file in $FUZZ_TEST_BINARIES_OUT_PATHS; do
  FUZZ_TESTS=$($fuzz_main_file --list_fuzz_tests | cut -d ' ' -f 4)
  cp -f ${fuzz_main_file} $OUT/
  fuzz_basename=$(basename $fuzz_main_file)
  chmod -x $OUT/$fuzz_basename
  for fuzz_entrypoint in $FUZZ_TESTS; do
    TARGET_FUZZER="${fuzz_basename}@$fuzz_entrypoint"

    # Write executer script
    echo "#!/bin/sh
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname \"\$0\")
chmod +x \$this_dir/$fuzz_basename
$fuzz_basename --fuzz=$fuzz_entrypoint -- \$@" > $OUT/$TARGET_FUZZER
    chmod +x $OUT/$TARGET_FUZZER
  done
done
popd
