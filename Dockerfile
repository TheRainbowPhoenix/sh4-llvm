# ==============================================================================
# STAGE 1: Build the Experimental LLVM Backend
# ==============================================================================
FROM debian:bookworm-slim AS llvm-builder

# Install host tools needed to compile LLVM
RUN apt-get -qq update && apt-get -y install \
    git cmake ninja-build clang lld python3

WORKDIR /build

# Clone the specific branch containing the experimental SH4 backend
RUN git clone --recurse-submodules --branch=sh4 https://github.com/KitsunebiGames/llvm-project.git

WORKDIR /build/llvm-project/build

# Configure and build LLVM
RUN cmake -G Ninja ../llvm \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX=/opt/llvm-sh4 \
    -DLLVM_ENABLE_PROJECTS="lld" \
    -DLLVM_ENABLE_DUMP=1 \
    -DLLVM_BINUTILS_INCDIR=/usr/include \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_BUILD_TOOLS=ON \
    -DLLVM_TARGETS_TO_BUILD="" \
    -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="SuperH" \
    -DLLVM_PARALLEL_LINK_JOBS=16 \
    -DLLVM_USE_LINKER=gold \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++

# Compile and install to /opt/llvm-sh4
RUN ninja -j$(nproc) install


# ==============================================================================
# STAGE 2: Final Minimal User Image
# ==============================================================================
FROM debian:bookworm-slim

ENV USERNAME="dev"
ENV LLVM_DIR=/opt/llvm-sh4
ENV PATH=${LLVM_DIR}/bin:$PATH

# Install basic development tools (make, nano, etc.)
RUN apt-get -qq update && apt-get -qqy install \
    make nano sudo git && apt-get -qqy clean

# Copy only the compiled LLVM toolchain from Stage 1
COPY --from=llvm-builder /opt/llvm-sh4 /opt/llvm-sh4

# Create a non-root user
RUN useradd -rm -d /home/$USERNAME -s /bin/bash -g root -G sudo -u 1001 $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER $USERNAME
WORKDIR /home/$USERNAME/workspace

CMD ["/bin/bash"]
