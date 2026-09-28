set project_name "button_uart_count"
set project_dir "build"
set part_number "GW1NR-LV9QN88PC6/I5"

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ".."]]

set verilog_files [list \
    [file join $repo_root "src" "button_debounce.v"] \
    [file join $repo_root "src" "press_counter.v"] \
    [file join $repo_root "src" "uart_rx.v"] \
    [file join $repo_root "src" "uart_tx.v"] \
    [file join $repo_root "src" "register_bus.v"] \
    [file join $repo_root "src" "command_parser.v"] \
    [file join $repo_root "src" "pwm_led.v"] \
    [file join $repo_root "src" "spi_master.v"] \
    [file join $repo_root "src" "sync_fifo.v"] \
    [file join $repo_root "src" "dot_product_accel.v"] \
    [file join $repo_root "src" "count_uart_sender.v"] \
    [file join $repo_root "src" "inmp441_i2s_rx.v"] \
    [file join $repo_root "src" "audio_band_analyzer.v"] \
    [file join $repo_root "src" "audio_uart_sender.v"] \
    [file join $repo_root "src" "top.v"] \
]
set cst_file [file join $repo_root "constraints" "tang_nano_9k.cst"]
set sdc_file [file join $repo_root "constraints" "tang_nano_9k.sdc"]
set build_dir [file join $repo_root "build"]

puts "Repository root: $repo_root"
puts "Verilog files: $verilog_files"
puts "Constraint file: $cst_file"
puts "Timing constraint file: $sdc_file"
puts "Build directory: $build_dir"

create_project -name $project_name -dir $build_dir -pn $part_number -device_version C -force

foreach verilog_file $verilog_files {
    add_file -type verilog $verilog_file
}
add_file -type cst $cst_file
add_file -type sdc $sdc_file

set_option -top_module top
set_option -output_base_name $project_name
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std v2001
set_option -global_freq 27

run all
run close
