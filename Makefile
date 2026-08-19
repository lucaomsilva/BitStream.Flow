# === Project Configuration ===
SHELL      := /bin/bash
DOCKER_TAG ?= v1.0
HOST_UID   := $(shell id -u)
HOST_GID   := $(shell id -g)

# Compile variables
PROJ            = top
TOP             = top
BUILD_DIR       = build
SRC_DIR         = rtl
CONSTRAINTS_DIR = syn/constraints
HDL            ?= Verilog

# Build files
JSON_FILE   = $(BUILD_DIR)/$(PROJ).json
PNR_FILE    = $(BUILD_DIR)/$(PROJ)_pnr.json
FS_FILE     = $(BUILD_DIR)/$(PROJ).fs

# Verilog/VHDL/SystemVerilog source files
ifeq ($(HDL),VHDL)
SRCS        = $(wildcard $(SRC_DIR)/*.vhd)
else ifeq ($(HDL),SystemVerilog)
SRCS        = $(wildcard $(SRC_DIR)/*.sv)
else
SRCS        = $(wildcard $(SRC_DIR)/*.v)
endif

# === Board Configuration (Tang Nano 9K) ===
# Parameters extracted from datasheets and toolchain documentation
BOARD       = tangnano9k
FAMILY      = GW1N-9C
DEVICE      = GW1NR-LV9QN88PC6/I5
PINS_FILE   = $(CONSTRAINTS_DIR)/$(PROJ).cst

# === Tool Definitions ===
YOSYS       = yosys
NEXTPNR     = nextpnr-himbaechel
PACKER      = gowin_pack
LOADER      = openFPGALoader

# === Colors ===
GREEN  := \033[32m
BLUE   := \033[34m
YELLOW := \033[33m
RED    := \033[31m
NC     := \033[0m

# Silence most command outputs
.SILENT:

##@ General

.PHONY: help
help: ## Display this help message
	@echo -e "$(BLUE)BitStream.Flow Makefile$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_0-9\/-]+:.*?##/ { printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Compilation Rules

.PHONY: lint
lint: ## Run static analysis (linting) on source files
	@echo -e "$(BLUE)>> Linting $(HDL) source files...$(NC)"
ifeq ($(HDL),VHDL)
	ghdl -s $(SRCS) || (echo -e "$(RED)Error: VHDL linting failed$(NC)"; exit 1)
else
	verible-verilog-lint $(SRCS) || (echo -e "$(RED)Error: Verilog/SV linting failed$(NC)"; exit 1)
endif
	@echo -e "$(GREEN)>> Linting complete.$(NC)"

# Default target: builds everything
.PHONY: all
all: $(FS_FILE) ## Build the bitstream (default)
	@echo -e "$(GREEN)Build complete. Bitstream generated at $(FS_FILE)$(NC)"

.PHONY: synth
synth: $(JSON_FILE) ## Run Synthesis (Yosys)

.PHONY: pnr
pnr: $(PNR_FILE) ## Run Place & Route (NextPNR)

.PHONY: pack
pack: $(FS_FILE) ## Run Packing (Gowin_Pack)

# Rule for synthesis (Verilog/VHDL/SystemVerilog -> JSON Netlist)
$(JSON_FILE): $(SRCS)
	@echo -e "$(BLUE)>> Synthesizing with Yosys ($(HDL))...$(NC)"
	@mkdir -p $(BUILD_DIR)
ifeq ($(HDL),VHDL)
	$(YOSYS) -m ghdl -p "ghdl $(SRCS) -e $(TOP); synth_gowin -json $(JSON_FILE)" || (echo -e "$(RED)Error during synthesis$(NC)"; exit 1)
else ifeq ($(HDL),SystemVerilog)
	$(YOSYS) -p "read_verilog -sv $(SRCS); synth_gowin -json $(JSON_FILE)" || (echo -e "$(RED)Error during synthesis$(NC)"; exit 1)
else
	$(YOSYS) -p "synth_gowin -json $(JSON_FILE)" $(SRCS) || (echo -e "$(RED)Error during synthesis$(NC)"; exit 1)
endif

# Rule for Place & Route (JSON Netlist -> PNR JSON)
$(PNR_FILE): $(JSON_FILE)
	@echo -e "$(BLUE)>> Executing Place & Route with nextpnr...$(NC)"
	$(NEXTPNR) --device $(DEVICE) --vopt family=$(FAMILY) --vopt cst=$(PINS_FILE) --json $(JSON_FILE) --write $(PNR_FILE) --freq 27 || (echo -e "$(RED)Error during Place & Route$(NC)"; exit 1)

# Rule for packing (PNR JSON -> Bitstream.fs)
$(FS_FILE): $(PNR_FILE)
	@echo -e "$(BLUE)>> Generating bitstream with gowin_pack...$(NC)"
	$(PACKER) -d $(FAMILY) -o $@ $< || (echo -e "$(RED)Error during Packing$(NC)"; exit 1)

##@ Programming Targets

# Program bitstream to Flash (non-volatile)
.PHONY: flash
flash: ## Program bitstream to Flash (non-volatile)
	@echo -e "$(BLUE)>> Programming to Flash with openFPGALoader...$(NC)"
	$(LOADER) -b $(BOARD) -f $(FS_FILE) || (echo -e "$(RED)Error flashing to board$(NC)"; exit 1)

# Program bitstream to SRAM (volatile, faster)
.PHONY: flash-sram
flash-sram: ## Program bitstream to SRAM (volatile, faster)
	@echo -e "$(BLUE)>> Programming to SRAM with openFPGALoader...$(NC)"
	$(LOADER) -m -b $(BOARD) $(FS_FILE) || (echo -e "$(RED)Error flashing SRAM$(NC)"; exit 1)

# Detect connected board
.PHONY: detect
detect: ## Detect connected board with openFPGALoader
	@echo -e "$(BLUE)>> Detecting board with openFPGALoader...$(NC)"
	$(LOADER) --detect || (echo -e "$(RED)Error: Board not detected$(NC)"; exit 1)

# Install necessary tools and udev rules on the host
.PHONY: install-tools
install-tools: ## Install necessary tools and udev rules on the host
	@echo -e "$(BLUE)>> Installing openFPGALoader from source (static version v1.1.1) and udev rules...$(NC)"
	sudo dnf install -y git cmake make gcc-c++ libftdi-devel libusb1-devel zlib-devel hidapi-devel && \
	git clone --branch v1.1.1 https://github.com/trabucayre/openFPGALoader /tmp/openFPGALoader && \
	cd /tmp/openFPGALoader && \
	mkdir build && cd build && \
	cmake .. && \
	make -j$$(nproc) && \
	sudo make install || (echo -e "$(RED)Error building openFPGALoader$(NC)"; exit 1)
	sudo cp dev-rules/99-openfpgaloader.rules /etc/udev/rules.d/
	sudo udevadm control --reload-rules && sudo udevadm trigger
	@echo -e "$(GREEN)>> Installation complete. Please replug your FPGA.$(NC)"
	@rm -rf /tmp/openFPGALoader

##@ Docker Environment

.PHONY: docker-build
docker-build: ## Build the Docker container locally
	@echo -e "$(BLUE)>> Building Docker container...$(NC)"
	sudo docker build -f ci/Dockerfile -t bitstream-flow:$(DOCKER_TAG) .

.PHONY: docker-shell
docker-shell: ## Start an interactive shell inside the Docker container
	@echo -e "$(BLUE)>> Starting interactive shell...$(NC)"
	sudo docker run --rm -it --user $(HOST_UID):$(HOST_GID) -v $$(pwd):/home/painter/canvas:z -w /home/painter/canvas bitstream-flow:$(DOCKER_TAG) bash

.PHONY: docker-lint
docker-lint: ## Run 'make lint' inside the Docker container
	@echo -e "$(BLUE)>> Running lint in container...$(NC)"
	sudo docker run --rm --user $(HOST_UID):$(HOST_GID) -v $$(pwd):/home/painter/canvas:z -w /home/painter/canvas bitstream-flow:$(DOCKER_TAG) make lint HDL=$(HDL)

.PHONY: docker-all
docker-all: ## Run 'make all' inside the Docker container
	@echo -e "$(BLUE)>> Running make all in container...$(NC)"
	sudo docker run --rm --user $(HOST_UID):$(HOST_GID) -v $$(pwd):/home/painter/canvas:z -w /home/painter/canvas bitstream-flow:$(DOCKER_TAG) make all HDL=$(HDL)

##@ Clean Target

.PHONY: clean
clean: ## Clean build directory
	@echo -e "$(YELLOW)>> Cleaning build directory...$(NC)"
	@rm -rf $(BUILD_DIR)
	@echo -e "$(GREEN)>> Clean complete.$(NC)"
