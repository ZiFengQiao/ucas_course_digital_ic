# ========== 配置部分 ==========
TEX = main.tex              # 主文件名（不带路径）
TARGET = main.pdf           # 输出 PDF 文件名
BIBFILE = references.bib     # 参考文献文件名（不带路径）
ENGINE = xelatex            # 编译引擎，可改为 lualatex

# ========== 默认目标：编译 ==========
all: $(TARGET)

$(TARGET): $(TEX) $(BIBFILE)
	$(ENGINE) $(TEX)
	biber $(basename $(TEX))
	$(ENGINE) $(TEX)
	$(ENGINE) $(TEX)
	@echo "编译完成：$(TARGET)"

# ========== 清理中间文件 ==========
clean:
	rm -f *.aux *.bbl *.blg *.log *.out *.toc *.lof *.lot *.fls *.fdb_latexmk *.xml *.bcf
	@echo "已清理中间文件"

# ========== 清理所有生成文件（包括 PDF） ==========
cleanall: clean
	rm -f $(TARGET)
	@echo "已删除生成的 PDF 文件"

# ========== 仅生成参考文献 ==========
bib:
	biber $(basename $(TEX))
	@echo "已更新参考文献"

# ========== 伪目标 ==========
.PHONY: all clean cleanall bib
