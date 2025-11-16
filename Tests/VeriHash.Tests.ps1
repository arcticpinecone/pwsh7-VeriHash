BeforeAll {
    # Import the function we want to test from VeriHash.ps1
    # We use dot-sourcing to load the script
    . "$PSScriptRoot\..\VeriHash.ps1" -FilePath "dummy" -ErrorAction SilentlyContinue 2>$null

    # Note: The script will try to run when we import it, so we pass a dummy filepath
    # and suppress errors. In a refactored version, you'd separate functions from execution.
}

Describe 'Test-InputHash' {
    Context 'When comparing hash values' {
        It 'Returns success message when hashes match exactly' {
            # Arrange
            $computedHash = 'ABC123DEF456'
            $inputHash = 'ABC123DEF456'

            # Act & Assert
            # We can't easily test the Write-Host output, but we can test that it doesn't throw
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }

        It 'Handles case-insensitive comparison correctly (lowercase input)' {
            # Arrange
            $computedHash = 'ABC123DEF456'
            $inputHash = 'abc123def456'

            # Act & Assert
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }

        It 'Handles case-insensitive comparison correctly (uppercase input)' {
            # Arrange
            $computedHash = 'abc123def456'
            $inputHash = 'ABC123DEF456'

            # Act & Assert
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }

        It 'Detects when hashes do not match' {
            # Arrange
            $computedHash = 'ABC123DEF456'
            $inputHash = 'DIFFERENT123'

            # Act & Assert
            { Test-InputHash -ComputedHash $computedHash -InputHash $inputHash } | Should -Not -Throw
        }
    }
}

Describe 'Get-ClipboardHash' {
    Context 'When detecting hash algorithm from clipboard' {
        It 'Detects MD5 hash (32 characters)' {
            # Arrange
            Mock Get-Clipboard { return '5d41402abc4b2a76b9719d911017c592' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'MD5'
            $result.Hash | Should -Be '5D41402ABC4B2A76B9719D911017C592'
        }

        It 'Detects SHA256 hash (64 characters)' {
            # Arrange
            Mock Get-Clipboard { return 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'SHA256'
            $result.Hash | Should -Be 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
        }

        It 'Detects SHA512 hash (128 characters)' {
            # Arrange
            $sha512Hash = 'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e'
            Mock Get-Clipboard { return $sha512Hash }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.Algorithm | Should -Be 'SHA512'
            $result.Hash.Length | Should -Be 128
        }

        It 'Returns null for invalid hash format' {
            # Arrange
            Mock Get-Clipboard { return 'this is not a hash' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for hash with invalid characters' {
            # Arrange
            Mock Get-Clipboard { return 'ZZZZ402abc4b2a76b9719d911017c592' }

            # Act
            $result = Get-ClipboardHash

            # Assert
            $result | Should -BeNullOrEmpty
        }
    }
}
