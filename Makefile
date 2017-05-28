# OS specific differences
UNAME = ${shell uname}
ifeq ($(UNAME), Darwin)
SWIFTC_FLAGS =
LINKER_FLAGS =
endif
ifeq ($(UNAME), Linux)
SWIFTC_FLAGS = -Xcc -I/usr/local/include
LINKER_FLAGS = -Xlinker -L/usr/local/lib

endif

debug:
	swift build $(SWIFTC_FLAGS) $(LINKER_FLAGS)

build:
	swift $(SWIFTC_FLAGS) $(LINKER_FLAGS)

test: build
	swift test $(SWIFTC_FLAGS) $(LINKER_FLAGS)

clean:
	swift build --clean

distclean:
	rm -rf Packages
	swift build --clean

.PHONY: build test distclean init
