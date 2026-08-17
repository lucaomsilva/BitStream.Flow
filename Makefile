# === Project Configuration ===
SHELL      := /bin/bash
DOCKER_TAG ?= v1.0

# Compile variables
PROJ            = top
TOP             = top
BUILD_DIR       = canvas
SRC_DIR         = rtl
CONSTRAINTS_DIR = syn/constraints
HDL            ?= Verilog

# Build files
JSON_FILE   = $(BUILD_DIR)/$(PROJ).json
PNR_FILE    = $(BUILD_DIR)/$(PROJ)_pnr.json
FS_FILE     = $(BUILD_DIR)/$(PROJ).fs

# Verilog source files
SRCS        = $(wildcard $(SRC_DIR)/*.v)

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

# Rule for synthesis (Verilog -> JSON Netlist)
$(JSON_FILE): $(SRCS)
	@echo -e "$(BLUE)>> Synthesizing with Yosys...$(NC)"
	@mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "synth_gowin -json $(JSON_FILE)" $(SRCS) || (echo -e "$(RED)Error during synthesis$(NC)"; exit 1)

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
	sudo docker run --rm -it -v $$(pwd):/project:z -w /project bitstream-flow:$(DOCKER_TAG) bash

.PHONY: docker-all
docker-all: ## Run 'make all' inside the Docker container
	@echo -e "$(BLUE)>> Running make all in container...$(NC)"
	sudo docker run --rm -v $$(pwd):/project:z -w /project bitstream-flow:$(DOCKER_TAG) make all

##@ Clean Target

.PHONY: clean
clean: ## Clean build directory
	@echo -e "$(YELLOW)>> Cleaning build directory...$(NC)"
	@rm -rf $(BUILD_DIR)
	@echo -e "$(GREEN)>> Clean complete.$(NC)"
