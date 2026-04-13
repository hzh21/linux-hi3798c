KDIR ?= linux-5.10
KCFG ?= sn1-5.10.config
CROSS_GCC ?= aarch64-linux-gnu-

DTB := hisilicon/hi3798cv200-imou-sn1.dtb

# 🎯 核心修改 1：干掉原有的 Git 动态获取逻辑，强行焊死后缀
FIXED_LOCALVERSION = -f425e7f

# 🎯 核心修改 2：把强制后缀直接塞进底层编译命令里，神仙都改不掉！
MAKE_ARCH = make -C $(KDIR) CROSS_COMPILE=$(CROSS_GCC) ARCH=arm64 LOCALVERSION="$(FIXED_LOCALVERSION)"

# 注意：KVER 必须放在 MAKE_ARCH 定义之后，因为它依赖 MAKE_ARCH 来获取准确的版本号
KVER = $(shell $(MAKE_ARCH) -s kernelrelease)

CUR_DIR := $(shell pwd)
STAGE_DIR := $(CUR_DIR)/stage
OUTPUT_DIR := $(CUR_DIR)/output
J=$(shell nproc)

all: kernel modules
	mkdir -p $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/Image $(OUTPUT_DIR)
	cp -f $(KDIR)/arch/arm64/boot/dts/$(DTB) $(OUTPUT_DIR)
	tar --owner=root --group=root -cJf $(OUTPUT_DIR)/modules.tar.xz -C $(STAGE_DIR) lib

$(KDIR)/.config: $(KCFG)
	cp -f $(KCFG) $(KDIR)/.config
	$(MAKE_ARCH) olddefconfig

kernel_version: $(KDIR)/.config
	@$(MAKE_ARCH) -s kernelrelease

kernel: $(KDIR)/.config
	@echo "Kernel source dir: $(KDIR)"
	$(MAKE_ARCH) -j$(J) Image dtbs

modules: $(KDIR)/.config
	rm -rf $(STAGE_DIR)
	$(MAKE_ARCH) -j$(J) modules
	$(MAKE_ARCH) INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$(STAGE_DIR) modules_install
	rm -f $(STAGE_DIR)/lib/modules/$(KVER)/build $(STAGE_DIR)/lib/modules/$(KVER)/source

kernel_clean:
	$(MAKE_ARCH) distclean

clean: kernel_clean
	rm -rf $(STAGE_DIR)
	rm -rf $(OUTPUT_DIR)
