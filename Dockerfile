# ==============================================================================
# STAGE 1: Build the Experimental LLVM Backend
# ==============================================================================
FROM debian:bullseye-slim AS llvm-builder

# Install host tools needed to compile LLVM
RUN apt-get -qq update && apt-get -y install \
    git cmake ninja-build clang lld python3

WORKDIR /build

# Clone the specific branch containing the experimental SH4 backend
RUN git clone --recurse-submodules --branch=sh4 https://github.com/KitsunebiGames/llvm-project.git

WORKDIR /build/llvm-project/build

# Configure and build LLVM
# - We use Release mode to save time and massively reduce the final binary size.
# - We set TARGETS_TO_BUILD to "host" so LLVM can build its internal tools (like tblgen).
# - We set EXPERIMENTAL_TARGETS_TO_BUILD to "SuperH" to get the SH4 backend.
RUN cmake -G Ninja ../llvm \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/opt/llvm-sh4 \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_TARGETS_TO_BUILD="host" \
    -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="SuperH" \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DLLVM_INCLUDE_BENCHMARKS=OFF \
    -DLLVM_BUILD_TOOLS=ON \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DLLVM_USE_LINKER=lld

# Compile and install to /opt/llvm-sh4
RUN ninja -j$(nproc) install


# ==============================================================================
# STAGE 2: Final Minimal User Image
# ==============================================================================
FROM debian:bullseye-slim

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
