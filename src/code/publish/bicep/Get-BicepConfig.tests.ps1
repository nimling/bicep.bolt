describe 'Get-BicepConfig'{
    BeforeEach{
        gci $testdrive|Remove-Item -Recurse -Force
    }

    it "should throw if file does not exist"{
        # $path = join-path $testdrive "test.txt"
        {Get-BicepConfig -Path $testdrive} | should -Throw
    }
}