$script:hgCommands = @()

function HgTabExpansion($lastBlock) {
  switch -regex ($lastBlock) { 
    
    #handles hg update <branch name>
    #handles hg merge <branch name>
    'hg (up|update|merge) (\S*)$' {
      hgLocalBranches($matches[2])
    }
    
    #Handles hg push <path>
    #Handles hg pull <path>
    'hg (push|pull) (-\S* )*(\S*)$' {
      hgRemotes($matches[3])
    }
    
    #handles hg help <cmd>
    #handles hg <cmd>
    'hg (help )?(\S*)$' {
      hgCommands($matches[2]);
    }

    #handles hg <cmd> --<option>
    'hg (\S+) (-\S* )*--(\S*)$' {
      hgOptions $matches[1] $matches[3];
    }
    
    #handles hg revert <path>
    'hg revert (\S*)$' {
      hgFiles $matches[1] 'M|A|R|!'
    }
    
    #handles hg add <path>
    'hg add (\S*)$' {
      hgFiles $matches[1] '\?'
    }
    
    #handles hgtk help <cmd>
    #handles hgtk <cmd>
    'hgtk (help )?(\S*)$' {
      hgtkCommands($matches[2]);
    }
    
    # handles hg diff <path>
    'hg diff (\S*)$' {
      hgFiles $matches[1] 'M'
    }
    
    # handles hg commit -(I|X) <path>
    'hg commit (\S* )*-(I|X) (\S*)$' {
      hgFiles $matches[3] 'M|A|R|!'
    }    
  }
}

function hgFiles($filter, $pattern) {
   hg status | 
    foreach { 
      if($_ -match "($pattern){1} (.*)") { 
        $matches[2] 
      } 
    } |
    where { $_ -like "*$filter*" } |
    foreach { if($_ -like '* *') {  "'$_'"  } else { $_ } }
}

function hgRemotes($filter) {
  hg paths | foreach {
    $path = $_.Split("=")[0].Trim();
    if($filter -and $path.StartsWith($filter)) {
      $path
    } elseif(-not $filter) {
      $path
    }
  }
}

# By default the hg command list is populated the first time hgCommands is invoked. 
# Invoke PopulateHgCommands in your profile if you don't want the initial hit. 
function hgCommands($filter) {
  if($script:hgCommands.Length -eq 0) {
    populateHgCommands
  }

  if($filter) {
     $hgCommands | ? { $_.StartsWith($filter) } | % { $_.Trim() } | sort  
  }
  else {
    $hgCommands | % { $_.Trim() } | sort
  }
}

# By default the hg command list is populated the first time hgCommands is invoked. 
# Invoke PopulateHgCommands in your profile if you don't want the initial hit. 
function PopulateHgCommands() {
   $hgCommands = (hg help) | % {
    if($_ -match '^ (\S+) (.*)') {
        $matches[1]
     }
  }

  if($global:PoshHgSettings.ShowPatches) {
    # MQ integration must be explicitly enabled as the user may not have the extension
    $hgCommands += (hg help mq) | % {
      if($_ -match '^ (\S+) (.*)') {
          $matches[1]
       }
    }
  }
  
  $script:hgCommands = $hgCommands
}

function hgLocalBranches($filter) {
  hg branches | foreach {
    if($_ -match "(\S+) .*") {
      if($filter -and $matches[1].StartsWith($filter)) {
        $matches[1]
      }
      elseif(-not $filter) {
        $matches[1]
      }
    }
  }
}

function hgOptions($cmd, $filter) {
	$optList = @()
	$output = hg help $cmd
	foreach($line in $output) {
		if($line -match '^ ((-\S)|  ) --(\S+) .*$') {
			$opt = $matches[3]
			if($filter -and $opt.StartsWith($filter)) {
				$optList += '--' + $opt.Trim()
			}
			elseif(-not $filter) {
				$optList += '--' + $opt.Trim()
			}
		}
	}

	$optList | sort
}

function hgtkCommands($filter) {
  $cmdList = @()
  $output = hgtk help
  foreach($line in $output) {
    if($line -match '^ (\S+) (.*)') {
      $cmd = $matches[1]
      if($filter -and $cmd.StartsWith($filter)) {
        $cmdList += $cmd.Trim()
      }
      elseif(-not $filter) {
        $cmdList += $cmd.Trim()
      }
    }
  }
  
  $cmdList | sort 
}