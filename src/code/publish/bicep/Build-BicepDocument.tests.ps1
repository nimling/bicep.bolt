describe 'Build-BicepDocument'{
    BeforeEach{
        gci $testdrive|Remove-Item -Recurse -Force
    }

    it "should throw if file is not bicep document"{
        $path = join-path $testdrive "test.txt"
        $out = join-path $testdrive "test.json"
        new-item -Path $path -ItemType File -Force | Out-Null
        {Build-BicepDocument -File $path -OutputFile $out} | should -Throw
    }
    it "should throw if file does not exist"{
        $path = join-path $testdrive "test.txt"
        $out = join-path $testdrive "test.json"
        # new-item -Path $path -ItemType File -Force | Out-Null
        {Build-BicepDocument -File $path -OutputFile $out} | should -Throw
    }
    it "should generate bicep document"{
        $path = join-path $testdrive "test.bicep"
        $out = join-path $testdrive "test.json"
        new-item -Path $path -ItemType File -Force | Out-Null
        Build-BicepDocument -File $path -OutputFile $out
        $out | should -Exist
    }
    it "should generate log"{
        $log = join-path $testdrive "test.log"
        $path = join-path $testdrive "test.bicep"
        $out = join-path $testdrive "test.json"
        new-item -Path $path -ItemType File -Force | Out-Null
        Build-BicepDocument -File $path -OutputFile $out -LogFile $log
        $log | should -Exist
    }
}