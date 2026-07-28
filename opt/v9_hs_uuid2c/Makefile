BIN_DIR = bin
SRC_DIR = src
TARGET  = $(BIN_DIR)/v9_hs_uuid2c

.PHONY: all build clean

all: build

build: $(TARGET)

$(TARGET): $(SRC_DIR)/Main.hs
	@mkdir -p $(BIN_DIR)
	ghc -O2 -i$(SRC_DIR) $< -o $@
	@rm -f $(SRC_DIR)/*.o $(SRC_DIR)/*.hi

clean:
	rm -rf $(BIN_DIR)
