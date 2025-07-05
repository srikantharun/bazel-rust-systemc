"""RTL build rules for Bazel - Memory Array compilation support"""

def _rtl_library_impl(ctx):
    """Implementation of rtl_library rule"""
    srcs = ctx.files.srcs
    deps = ctx.files.deps
    
    # Collect all Verilog files
    verilog_files = []
    for src in srcs:
        if src.extension in ["v", "sv", "vh", "svh"]:
            verilog_files.append(src)
    
    # Create output file
    output = ctx.actions.declare_file(ctx.label.name + ".rtl.db")
    
    # Build command
    args = ctx.actions.args()
    args.add_all(["-o", output])
    args.add_all(verilog_files)
    args.add_all(deps)
    
    ctx.actions.run(
        inputs = verilog_files + deps,
        outputs = [output],
        executable = ctx.executable._compiler,
        arguments = [args],
        mnemonic = "RTLCompile",
        progress_message = "Compiling RTL library %s" % ctx.label.name,
    )
    
    return [
        DefaultInfo(files = depset([output])),
        OutputGroupInfo(
            rtl_db = depset([output]),
            sources = depset(verilog_files),
        ),
    ]

def _rtl_macro_gen_impl(ctx):
    """Implementation of rtl_macro_gen rule for template-based generation"""
    template = ctx.file.template
    outputs = []
    
    for output_name in ctx.attr.outputs:
        output = ctx.actions.declare_file(output_name)
        outputs.append(output)
        
        # Extract parameters from output filename
        import_re = "array_([0-9]+)x([0-9]+)"
        
        args = ctx.actions.args()
        args.add_all(["--template", template])
        args.add_all(["--output", output])
        args.add_all(["--params", output_name])
        
        ctx.actions.run(
            inputs = [template],
            outputs = [output],
            executable = ctx.executable._generator,
            arguments = [args],
            mnemonic = "RTLGenerate",
            progress_message = "Generating %s from template" % output_name,
        )
    
    return [DefaultInfo(files = depset(outputs))]

def _rtl_synthesis_impl(ctx):
    """Implementation of rtl_synthesis rule"""
    rtl_lib = ctx.attr.rtl_lib[OutputGroupInfo].rtl_db.to_list()[0]
    
    # Synthesis outputs
    netlist = ctx.actions.declare_file(ctx.label.name + ".netlist.v")
    timing = ctx.actions.declare_file(ctx.label.name + ".timing.rpt")
    area = ctx.actions.declare_file(ctx.label.name + ".area.rpt")
    
    args = ctx.actions.args()
    args.add_all(["-i", rtl_lib])
    args.add_all(["-o", netlist])
    args.add_all(["--timing", timing])
    args.add_all(["--area", area])
    args.add_all(["--target", ctx.attr.target_library])
    
    ctx.actions.run(
        inputs = [rtl_lib],
        outputs = [netlist, timing, area],
        executable = ctx.executable._synthesizer,
        arguments = [args],
        mnemonic = "RTLSynthesize",
        progress_message = "Synthesizing %s" % ctx.label.name,
    )
    
    return [
        DefaultInfo(files = depset([netlist, timing, area])),
        OutputGroupInfo(
            netlist = depset([netlist]),
            reports = depset([timing, area]),
        ),
    ]

# Rule definitions
rtl_library = rule(
    implementation = _rtl_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".v", ".sv", ".vh", ".svh"],
            doc = "Verilog/SystemVerilog source files",
        ),
        "deps": attr.label_list(
            allow_files = [".db"],
            doc = "RTL library dependencies",
        ),
        "_compiler": attr.label(
            default = "@rtl_tools//:iverilog",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Compiles Verilog/SystemVerilog files into an RTL library",
)

rtl_macro_gen = rule(
    implementation = _rtl_macro_gen_impl,
    attrs = {
        "template": attr.label(
            allow_single_file = [".jinja2", ".j2"],
            mandatory = True,
            doc = "Jinja2 template file",
        ),
        "outputs": attr.string_list(
            mandatory = True,
            doc = "List of output files to generate",
        ),
        "_generator": attr.label(
            default = "@rtl_tools//:jinja_gen",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Generates RTL files from Jinja2 templates",
)

rtl_synthesis = rule(
    implementation = _rtl_synthesis_impl,
    attrs = {
        "rtl_lib": attr.label(
            mandatory = True,
            providers = [OutputGroupInfo],
            doc = "RTL library to synthesize",
        ),
        "target_library": attr.string(
            default = "generic",
            doc = "Target technology library",
        ),
        "_synthesizer": attr.label(
            default = "@rtl_tools//:yosys",
            executable = True,
            cfg = "exec",
        ),
    },
    doc = "Synthesizes RTL to gate-level netlist",
)

def memory_array(name, size, cell_type, precision = "int8", power_mode = "balanced", **kwargs):
    """High-level macro for building memory arrays"""
    
    rows, cols = size.split('x')
    total_cells = int(rows) * int(cols)
    
    # Generate appropriate hierarchy based on size
    if total_cells > 1_000_000:
        tile_size = 64
        bank_size = 256
        build_strategy = "distributed"
    elif total_cells > 100_000:
        tile_size = 32
        bank_size = 128
        build_strategy = "parallel"
    else:
        tile_size = 16
        bank_size = 64
        build_strategy = "single"
    
    # Generate cell array templates
    rtl_macro_gen(
        name = name + "_arrays_gen",
        template = "//tools/rtl/templates:cell_array.v.jinja2",
        outputs = [
            "gen/array_%dx%d.v" % (tile_size, tile_size),
            "gen/bank_%dx%d.v" % (bank_size, bank_size),
        ],
    )
    
    # Build the memory cell
    rtl_library(
        name = name + "_cell",
        srcs = ["//rtl/cells:%s_cell.v" % cell_type],
        **kwargs
    )
    
    # Build the tile
    rtl_library(
        name = name + "_tile",
        srcs = [":" + name + "_arrays_gen"],
        deps = [":" + name + "_cell"],
        **kwargs
    )
    
    # Build the full array
    if build_strategy == "distributed":
        # Split into partitions for very large arrays
        partitions = []
        for i in range(4):
            rtl_library(
                name = name + "_partition_%d" % i,
                srcs = ["//rtl/memory:partition_%d.v" % i],
                deps = [":" + name + "_tile"],
                **kwargs
            )
            partitions.append(":" + name + "_partition_%d" % i)
        
        # Merge partitions
        rtl_library(
            name = name,
            srcs = ["//rtl/memory:array_top.v"],
            deps = partitions,
            **kwargs
        )
    else:
        # Direct build for smaller arrays
        rtl_library(
            name = name,
            srcs = ["//rtl/memory:array_%s.v" % size],
            deps = [":" + name + "_tile"],
            **kwargs
        )
    
    # Optional synthesis
    if kwargs.get("synthesize", False):
        rtl_synthesis(
            name = name + "_synth",
            rtl_lib = ":" + name,
            target_library = kwargs.get("target_library", "generic"),
        )