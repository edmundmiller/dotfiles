# neotest-nftest

A [neotest](https://github.com/nvim-neotest/neotest) adapter for [nf-test](https://www.nf-test.com/), the testing framework for Nextflow pipelines.

## Features

- **Test Discovery**: Automatically discovers nf-test files and test cases
- **Multiple Test Types**: Supports `nextflow_process`, `nextflow_workflow`, `nextflow_pipeline`, and `nextflow_function` tests
- **Flexible Execution**: Run individual tests, files, or entire test suites
- **Rich Output**: Displays test results with detailed error information
- **Profile Support**: Run tests with specific nf-test profiles
- **Integration**: Seamlessly integrates with LazyVim test framework

## Prerequisites

1. **nf-test**: Must be installed and available in your PATH
   ```bash
   # Install nf-test
   curl -fsSL https://get.nf-test.com | bash
   ```

2. **Nextflow**: Required for running Nextflow pipelines
   ```bash
   # Install Nextflow
   curl -s https://get.nextflow.io | bash
   ```

3. **Treesitter**: Groovy parser for syntax highlighting
   ```vim
   :TSInstall groovy
   ```

## Usage

### Running Tests

| Keybinding | Action |
|------------|--------|
| `<leader>tt` | Run nearest test |
| `<leader>tf` | Run all tests in current file |
| `<leader>ta` | Run all tests in project |
| `<leader>ts` | Toggle test summary |
| `<leader>to` | Show test output |
| `<leader>tO` | Toggle output panel |
| `<leader>tS` | Stop running tests |
| `<leader>tw` | Watch file for changes |

### nf-test Specific Features

| Keybinding | Action |
|------------|--------|
| `<leader>tn` | Run test with specific profile |
| `<leader>tc` | Run test with custom config |
| `<leader>td` | Run test with debug output |

### Navigation

| Keybinding | Action |
|------------|--------|
| `]t` | Jump to next failed test |
| `[t` | Jump to previous failed test |

## Test File Structure

The adapter recognizes nf-test files with the following patterns:

1. **Files ending with `.nf.test`**
2. **Files in `tests/` directory ending with `.nf`**
3. **Any `.nf` file containing `nextflow_*` test blocks**

### Example Test File

```groovy
nextflow_process {
    name "Test Process HELLO"
    script "modules/hello.nf"
    process "HELLO"
    
    test("Should greet user") {
        when {
            process {
                """
                input[0] = Channel.from('World')
                """
            }
        }
        
        then {
            assert process.success
            assert process.out.greeting.get(0).contains("Hello World")
        }
    }
    
    test("Should handle empty input") {
        when {
            process {
                """
                input[0] = Channel.empty()
                """
            }
        }
        
        then {
            assert process.success
            assert process.out.greeting.size() == 0
        }
    }
}
```

## Configuration

The adapter can be configured in your neotest setup:

```lua
require("neotest").setup({
  adapters = {
    require("neotest-nftest").setup({
      -- Extra arguments to pass to nf-test
      args = {},
      
      -- Default profile to use
      profile = nil,
      
      -- Custom config file path
      config_file = nil,
    })
  }
})
```

## Supported Test Types

### Process Tests (`nextflow_process`)
Test individual Nextflow processes in isolation.

### Workflow Tests (`nextflow_workflow`)
Test complete Nextflow workflows with multiple processes.

### Pipeline Tests (`nextflow_pipeline`)
Test entire Nextflow pipelines end-to-end.

### Function Tests (`nextflow_function`)
Test Nextflow functions and utility code.

## Output Formats

The adapter supports multiple output formats:

1. **JUnit XML**: Preferred format for detailed test results
2. **Console Output**: Falls back to parsing stdout/stderr
3. **Debug Mode**: Enhanced output with debugging information

## Troubleshooting

### Tests Not Discovered

1. Ensure files match expected patterns (`.nf.test` or contain `nextflow_*` blocks)
2. Verify nf-test is properly initialized in your project (`nf-test init`)
3. Check that Groovy treesitter parser is installed (`:TSInstall groovy`)

### Tests Not Running

1. Verify nf-test is in your PATH (`which nf-test`)
2. Check that your project has a valid `nf-test.config`
3. Ensure Nextflow is available (`which nextflow`)

### No Test Results

1. Check nf-test output format compatibility
2. Verify file permissions for temp result files
3. Enable debug mode with `<leader>td` for detailed output

## Contributing

This adapter is part of the LazyVim configuration. To contribute:

1. Test with various nf-test scenarios
2. Report issues with specific test file examples
3. Suggest improvements for better Nextflow integration

## Related Projects

- [nf-test](https://www.nf-test.com/) - Testing framework for Nextflow
- [neotest](https://github.com/nvim-neotest/neotest) - Neovim testing framework
- [Nextflow](https://www.nextflow.io/) - Workflow management system