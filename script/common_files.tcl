# get_design_files: 获取指定目录下的所有 .v 和 .sv 文件
proc get_design_files {RTL_DIR} {
    set design_files {}

    set files [glob -nocomplain -directory $RTL_DIR *]

    # 遍历文件并检查文件扩展名
    foreach file $files {
        if {[file extension $file] == ".v" || [file extension $file] == ".sv"} {
            lappend design_files [file normalize $file]
        }
    }

    # 返回文件列表
    return $design_files
}

# 脚本测试
set RTL_DIR "../../src"
set files [get_design_files $RTL_DIR]
puts "Design Files: $files"