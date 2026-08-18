# BitStream.Flow

An automated, containerized workflow for FPGA synthesis, Place & Route (P&R), and bitstream uploading using open-source tools.

---

### Project Overview
**BitStream.Flow** is a streamlined, containerized CI/CD workflow designed for FPGA development targeting the **Sipeed TangNano9k FPGA**.
It abstracts the complexity of open-source toolchains (Yosys, NextPNR, OpenFPGALoader, GHDL, Verible) by providing a ready-to-use Docker environment. This allows developers to focus on HDL coding while ensuring a consistent, automated path from source code to physical bitstream.

**Theme:** The project adopts a painting analogy for its environment:
- The Developer: **painter**
- Docker Image: **atelier**
- Docker Container: **easel**
- Build Folder: **canvas/**

---

### Table of Contents
1. [Features](#1--features)
2. [Hardware Development Pipeline](#2-️-hardware-development-pipeline)
3. [Repository Structure](#3--repository-structure)
4. [Docker Environment](#4--docker-environment)
5. [Makefile & Local Usage](#5-️-makefile--local-usage)
6. [CI/CD Pipeline Details](#6--cicd-pipeline-details)
7. [Customizing for Other Boards](#7--customizing-for-other-boards)
8. [Tool Reference Commands](#8--tool-reference-commands)

---

### 1. ✨ Features
* **Zero-Install Environment:** All tools are pre-configured inside a Docker container.
* **Hardware Agnostic:** Easily portable to different FPGA families and boards.
* **Multi-HDL Support:** Native synthesis and linting for **Verilog**, **SystemVerilog**, and **VHDL**.
* **Automated CI/CD:** Integrated GitHub Actions for building, linting, validating, and publishing bitstream releases.
* **Simplified Orchestration:** Clean `Makefile` interface for complex toolchain commands.

---

### 2. 🛠️ Hardware Development Pipeline
The hardware lifecycle in this project follows a rigorous 7-stage sequence, ensuring logical correctness before physical synthesis:

1. **Linting & Formatting:** Validates syntax and coding standards using `Verible` (Verilog/SV) or `GHDL` (VHDL).
2. **Functional Validation & Simulation:** *(Not Yet Implemented)* Executes testbenches (in `sim/`) to guarantee circuit logic under different input vectors.
3. **Formal Verification (Optional):** *(Not Yet Implemented)* Uses mathematical solvers (SAT/SMT) to prove properties exhaustively.
4. **Logical Synthesis:** Translates high-level RTL into a netlist using `Yosys`.
5. **Place & Route (P&R):** Physically allocates the netlist elements inside the FPGA applying constraints (`.cst`) using `nextpnr-himbaechel`.
6. **Bitstream Packing:** Converts the layout into a proprietary binary file (`.fs`) using `gowin_pack`.
7. **Hardware Deploy:** Flashes the binary to the FPGA's SRAM or Flash using `openFPGALoader`.

---

## 3. 📂 Repository Structure

This repository is structured to separate design files, constraints, and build artifacts, promoting a clean and organized workflow.

```
.
├── .github/workflows/  # GitHub Actions CI/CD pipelines
│   ├── ci.yml          # Continuous Integration (Lint & Build)
│   └── cd.yml          # Continuous Deployment (GitHub Releases)
├── docs/               # In-depth project documentation
├── rtl/                # Verilog (.v), VHDL (.vhd), or SystemVerilog (.sv) source files
├── sim/                # Testbenches and simulation-related files
├── syn/
│   └── constraints/    # Physical Constraint Files (.cst) for pin mapping
├── ci/
│   └── Dockerfile      # The 'atelier' Docker environment configuration
└── Makefile            # The orchestrator for the entire build process
```

- **`canvas/`**: Automatically created to store all output files from the build process (ignored by Git).
- **`rtl/`**: Primary HDL source files.
- **`sim/`**: Dedicated folder for testbench files.

---

## 4. 🐳 Docker Environment

The `ci/Dockerfile` builds the **atelier** image, a complete open-source toolchain for FPGAs based on Ubuntu 24.04.

### 1. Build and Push (Registry)
To build your own image and upload it to the GitHub Container Registry (GHCR):

```bash
# Export your Personal Access Token (PAT) with write:packages scope
echo "YOUR_GITHUB_PAT" | docker login ghcr.io -u <your-username> --password-stdin

# Build the image locally
docker build -f ci/Dockerfile -t ghcr.io/<your-username>/<your-repo-name>/atelier:latest .

# Push the image to your registry
docker push ghcr.io/<your-username>/<your-repo-name>/atelier:latest
```

### 2. Interactive Shell (The Easel)
Enter an interactive shell inside the container with your project mounted to compile or debug manually:
```bash
make docker-shell
```

### 3. Local Verification (Quick Run)
To completely validate your code without installing tools on your host OS:
```bash
# Run linting in the container
make docker-lint HDL=Verilog

# Run full synthesis and packing in the container
make docker-all HDL=Verilog
```
*(The Makefile automatically manages the SELinux `:z` flag and file ownership when building via Docker).*

---

## 5. ⚙️ Makefile & Local Usage

The `Makefile` orchestrates the toolchain. By default, it targets the **Tang Nano 9K** (GW1N-9C).

| Command | Description |
| :--- | :--- |
| `make all` | **Default.** Runs synthesis, P&R, and generates the final bitstream (`.fs`). |
| `make lint` | Runs static analysis (`Verible` for Verilog/SV, `GHDL` for VHDL). |
| `make flash` | Programs the bitstream to the **Flash** memory (non-volatile). |
| `make flash-sram` | Programs the bitstream to **SRAM** (volatile, faster testing). |
| `make detect` | Verifies if the FPGA is correctly connected. |
| `make install-tools`| Compiles `openFPGALoader` from source on Fedora/Ubuntu and sets udev rules. |
| `make clean` | Removes the `canvas/` directory and all generated artifacts. |

### HDL Selection
You can dynamically switch the targeted language by passing the `HDL` variable:
```bash
make all HDL=VHDL
make all HDL=SystemVerilog
```

---

## 6. 🔄 CI/CD Pipeline Details

The automation is powered by **GitHub Actions**. It ensures every change is syntactically correct and automatically deploys bitstreams.

### 1. Continuous Integration (`ci.yml`)
- **Trigger:** Runs on `push` or `pull_request` to `main`/`develop`, and on tag pushes.
- **Build Image:** Builds the `atelier` Docker environment and caches it in GHCR.
- **Linting:** Executes `make lint` inside the container for static analysis.
- **Compilation:** Executes `make all` to generate the `.fs` bitstream.
- **Artifact:** Uploads the generated `canvas/` folder as a GitHub artifact (`bitstream-<HDL>-<DATE>-<ID>-<VERSION>`).

### 2. Continuous Deployment (`cd.yml`)
- **Trigger:** Called automatically by `ci.yml` when a new version tag (e.g., `v1.0.0`) is pushed.
- **Action:** Downloads the CI artifact, renames the `.fs` file to match the tag, and automatically publishes a **GitHub Release** with the downloadable bitstream attached.

---

## 7. 🔧 Customizing for Other Boards

This repository is hardware-agnostic. To adapt it for other FPGA boards, modify the specific variables at the top of the `Makefile`:

* **`PROJ` & `TOP`**: Your project name and top-level module.
* **`BOARD`**: Identifier used by `openFPGALoader` (e.g., `icebreaker`, `tangnano4k`).
* **`FAMILY` & `DEVICE`**: Match your specific FPGA chip model.
* **`PINS_FILE`**: Change constraints extension (`.cst` for Gowin, `.pcf` for Lattice).
* **`NEXTPNR` & `PACKER`**: Change `nextpnr-himbaechel` to `nextpnr-ice40` or `nextpnr-ecp5` depending on your chip.

---

## 8. 📚 Tool Reference Commands

### 1. Linting & Formatting
```bash
verible-verilog-lint --help_rules
ghdl --help
```

### 2. Synthesis & P&R (Yosys & NextPNR)
```bash
yosys -p "help synth_gowin"
nextpnr-himbaechel --help
```

### 3. Programmer (openFPGALoader)
```bash
openFPGALoader --list-boards
openFPGALoader --list-cables
```
