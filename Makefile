#
#  DYUpdateBlock —— 屏蔽抖音启动强制更新弹窗（默认生效，无设置项）
#

TARGET = iphone:clang:latest:14.0
ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = Aweme

DY_VERSION := $(shell awk -F': *' '$$1 == "Version" { print $$2; exit }' control)
DYUPDATEBLOCK_PACKAGE_SCHEME ?= $(if $(THEOS_PACKAGE_SCHEME),$(THEOS_PACKAGE_SCHEME),rootful)

ifeq ($(strip $(DY_VERSION)),)
$(error Missing Version in control)
endif

ifeq ($(DYUPDATEBLOCK_PACKAGE_SCHEME),rootful)
unexport THEOS_PACKAGE_SCHEME
DYUPDATEBLOCK_PACKAGE_SUFFIX = arm-rootful
else ifeq ($(DYUPDATEBLOCK_PACKAGE_SCHEME),rootless)
export THEOS_PACKAGE_SCHEME = rootless
DYUPDATEBLOCK_PACKAGE_SUFFIX = arm64-rootless
else ifeq ($(DYUPDATEBLOCK_PACKAGE_SCHEME),roothide)
export THEOS_PACKAGE_SCHEME = roothide
DYUPDATEBLOCK_PACKAGE_SUFFIX = arm64e-roothide
else
$(error Unsupported DYUPDATEBLOCK_PACKAGE_SCHEME: $(DYUPDATEBLOCK_PACKAGE_SCHEME))
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DYUpdateBlock
DYUpdateBlock_FILES = DYUpdateBlock.xm
DYUpdateBlock_CFLAGS = -fobjc-arc -w
DYUpdateBlock_FRAMEWORKS = UIKit Foundation
DYUpdateBlock_LOGOS_DEFAULT_GENERATOR = internal

export THEOS_STRICT_LOGOS = 0
export ERROR_ON_WARNINGS = 0
export LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk

clean::
	@rm -rf .theos packages

package-rootful::
	@rm -rf .theos
	@$(MAKE) all package DYUPDATEBLOCK_PACKAGE_SCHEME=rootful FINALPACKAGE=1

package-rootless::
	@rm -rf .theos
	@$(MAKE) all package DYUPDATEBLOCK_PACKAGE_SCHEME=rootless FINALPACKAGE=1

package-roothide::
	@if [ -d "$(THEOS_VENDOR_MODULE_PATH)/roothide" ] || [ -d "$(THEOS_MODULE_PATH)/roothide" ]; then \
		rm -rf .theos; \
		$(MAKE) all package DYUPDATEBLOCK_PACKAGE_SCHEME=roothide FINALPACKAGE=1; \
	elif [ "$$GITHUB_ACTIONS" = "true" ]; then \
		echo "error: roothide Theos package scheme is required in CI."; \
		exit 1; \
	else \
		echo "warning: roothide Theos package scheme not found; skipped roothide package."; \
	fi

all-packages::
	@rm -rf packages
	@mkdir -p packages
	@$(MAKE) package-rootful FINALPACKAGE=1
	@$(MAKE) package-rootless FINALPACKAGE=1
	@$(MAKE) package-roothide FINALPACKAGE=1

before-package::
ifneq ($(THEOS_PACKAGE_INSTALL_PREFIX),)
	@mkdir -p "$(_THEOS_SCHEME_STAGE)"
endif

after-package::
	@mkdir -p packages
	@DEB=$$(cat "$(_THEOS_LOCAL_DATA_DIR)/last_package" 2>/dev/null || true); \
	 OUT="packages/DYUpdateBlock_$(DY_VERSION)_$(DYUPDATEBLOCK_PACKAGE_SUFFIX).deb"; \
	 if [ -n "$$DEB" ] && [ -f "$$DEB" ]; then mv -f "$$DEB" "$$OUT"; fi
	@if [ "$(DYUPDATEBLOCK_PACKAGE_SCHEME)" = "rootful" ]; then \
		DYLIB="$(THEOS_OBJ_DIR)/DYUpdateBlock.dylib"; \
		if [ -n "$$DYLIB" ]; then cp -f "$$DYLIB" packages/DYUpdateBlock.dylib; fi; \
	fi
	@echo "==> 成品: packages/DYUpdateBlock_$(DY_VERSION)_$(DYUPDATEBLOCK_PACKAGE_SUFFIX).deb"
