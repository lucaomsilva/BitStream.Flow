# ==============================================================================
# Stage 1: "builder" - Compiles the full toolchain from source
# ==============================================================================
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && apt-get install -y \
    build-essential \
    clang=1:18.0-59~exp2 \
    cmake=3.28.3-1build7 \
    bison=2:3.8.2+dfsg-1build2 \
    flex=2.6.4-8.2build1 \
    libreadline-dev=8.2-4build1 \
    gawk=1:5.2.1-2build3 \
    tcl-dev=8.6.14build1 \
    libffi-dev=3.4.6-1build1 \
    git=1:2.43.0-1ubuntu7 \
    graphviz=2.42.2-9build1 \
    xdot=1.3-1 \
    pkg-config=1.8.1-2build1 \
    gnat=13.2ubuntu2  \
    python3=3.12.3-0ubuntu2.1 \
    python3-dev=3.12.3-0ubuntu2.1 \
    python3-pip=24.0+dfsg-1ubuntu1 \
    libboost-all-dev=1.83.0.1ubuntu2 \
    libeigen3-dev=3.4.0-4 \
    libftdi1-dev=1.5-6build5 \
    zlib1g-dev=1:1.3.dfsg-3.1ubuntu2.1 \
    wget=1.21.4-1ubuntu4 \
    curl=8.5.0-2ubuntu10.11 \
    llvm=1:18.0-59~exp2 \
    libncurses-dev=6.4+20240113-1ubuntu2.1 \
    xz-utils=5.6.1+really5.4.5-1 \
    tk-dev=8.6.14build1 \
    libxml2-dev=2.9.14+dfsg-1.3ubuntu3.8 \
    libxmlsec1-dev=1.2.39-5build2 \
    liblzma-dev=5.6.1+really5.4.5-1ubuntu0.3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Install Apycula v0.32 (Required by NextPNR for gowin_bba)
RUN pip3 install --break-system-packages apycula==0.32

ENV PATH="/root/.local/bin:/usr/local/bin:${PATH}"

# Compile Yosys (static version v0.68)
RUN git clone --branch v0.68 https://github.com/YosysHQ/yosys.git && \
    cd yosys && \
    git submodule update --init && \
    cmake -B build . && \
    cmake --build build -j$(nproc) && \
    cmake --install build

# Compile GHDL (static version v4.1.0)
RUN git clone https://github.com/ghdl/ghdl.git && \
    cd ghdl && \
    ./configure --prefix=/usr/local --enable-synth --enable-libghdl && \
    make -j$(nproc) && \
    make install

# Compile ghdl-yosys-plugin
RUN git clone https://github.com/ghdl/ghdl-yosys-plugin.git && \
    cd ghdl-yosys-plugin && \
    git checkout master && \
    make GHDL=ghdl YOSYS_CONFIG=yosys-config -j$(nproc) && \
    make install

# Compile nextpnr-himbaechel (static version nextpnr-0.10)
RUN git clone --branch nextpnr-0.10 https://github.com/YosysHQ/nextpnr.git && \
    cd nextpnr && \
    mkdir build && \
    cd build && \
    cmake .. -DARCH="himbaechel" \
             -DHIMBAECHEL_UARCH="gowin" \
             -DGOWIN_BBA_EXECUTABLE=$(which gowin_bba) && \
    make -j$(nproc) && \
    make install

# ==============================================================================
# Stage 2: "runtime" - Lean image with only runtime dependencies
# ==============================================================================
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ENV PATH="/root/.local/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    libboost-program-options-dev=1.83.0.1ubuntu2 \
    libboost-filesystem-dev=1.83.0.1ubuntu2 \
    libboost-thread-dev=1.83.0.1ubuntu2 \
    libboost-iostreams-dev=1.83.0.1ubuntu2 \
    python3=3.12.3-0ubuntu2.1 \
    python3-pip=24.0+dfsg-1ubuntu1 \
    tcl=8.6.14build1 \
    make=4.3-4.1build2 \
    gnat=13.2ubuntu2 \
    && rm -rf /var/lib/apt/lists/*

# Re-install Apycula in runtime stage
RUN pip3 install --break-system-packages apycula==0.32

COPY --from=builder /usr/local/bin/yosys* /usr/local/bin/
COPY --from=builder /usr/local/bin/nextpnr-himbaechel /usr/local/bin/
COPY --from=builder /usr/local/bin/gowin_pack /usr/local/bin/
COPY --from=builder /usr/local/bin/ghdl* /usr/local/bin/
COPY --from=builder /usr/local/lib/ghdl/ /usr/local/lib/ghdl/
COPY --from=builder /usr/local/share/yosys/ /usr/local/share/yosys/
COPY --from=builder /usr/local/share/nextpnr/ /usr/local/share/nextpnr/

COPY --from=builder /usr/local/lib/libghdl* /usr/local/lib/
COPY --from=builder /usr/local/share/yosys/plugins/ghdl.so /usr/local/share/yosys/plugins/
RUN ldconfig

WORKDIR /project

# ==============================================================================
# Stage 3: "synthesis" - Copies project and runs Yosys
# ==============================================================================
FROM runtime AS synthesis

COPY . /project

RUN make synth

# ==============================================================================
# Stage 4: "pnr" - Runs Place & Route
# ==============================================================================
FROM synthesis AS pnr

RUN make pnr

# ==============================================================================
# Stage 5: "packing" - Generates the bitstream
# ==============================================================================
FROM pnr AS packing

RUN make pack