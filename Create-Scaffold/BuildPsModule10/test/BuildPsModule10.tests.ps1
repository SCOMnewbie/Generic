param (
    $ModuleName
)

Describe "$ModuleName Module" {
    Context 'Should import the module correctly' {

        It 'Should have at least one public function' {
            (Get-Command -Module $ModuleName).Count | Should -BeGreaterThan 1
        }
    }
}
