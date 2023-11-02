
task generate_target {
    
}

task prepare_starterpack {
    if (test-path $target.path ) {
        gci $target.path | remove-item -recurse -force
    } else {
        new-item -path $target.path -itemtype directory
    }
}