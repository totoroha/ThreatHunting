﻿function Hunt-ArpCache {
    <#
    .Synopsis 
        Gets the arp cache for the given computer(s).

    .Description 
        Gets the arp cache from all connected interfaces for the given computer(s).

    .Parameter Computer  
        Computer can be a single hostname, FQDN, or IP address.

    .Parameter Fails  
        Provide a path to save failed systems to.

    .Example 
        Hunt-ArpCache 
        Hunt-ArpCache  SomeHostName.domain.com
        Get-Content C:\hosts.csv | Hunt-ArpCache
        Hunt-ArpCache -Computer $env:computername
        Get-ADComputer -filter * | Select -ExpandProperty Name | Hunt-ArpCache

    .Notes 
        Updated: 2017-10-19

        Contributing Authors:
            Jeremy Arnold
            Anthony Phipps
            
        LEGAL: Copyright (C) 2017
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.
    
        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this program.  If not, see <http://www.gnu.org/licenses/>.
    #>

    param(
    	[Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        $Computer = $env:COMPUTERNAME,
        [Parameter()]
        $Fails
    );

	begin{

        $datetime = Get-Date -Format "yyyy-MM-dd_hh.mm.ss.ff";
        Write-Information -MessageData "Started at $datetime" -InformationAction Continue;

        $stopwatch = New-Object System.Diagnostics.Stopwatch;
        $stopwatch.Start();
        $total = 0;

        class ArpCache
        {
            [string] $Computer
            [Datetime] $DateScanned

            [String] $IfIndex
            [string] $InterfaceAlias
            [String] $IPAdress
            [String] $LinkLayerAddress
            [String] $State
            [String] $PolicyStore
        };
	};

    process{
            
        $Computer = $Computer.Replace('"', '');  # get rid of quotes, if present
        
        
        $arpCache = Invoke-Command -ComputerName $Computer -ErrorAction SilentlyContinue -ScriptBlock {
            Get-NetNeighbor | 
            Where-Object {($_.LinkLayerAddress -ne "") -and
                ($_.LinkLayerAddress -ne "FF-FF-FF-FF-FF-FF") -and # Broadcast. Filtered by LinkLayerAddress rather than "$_.State -ne "permanent" to maintain manual entries
                ($_.LinkLayerAddress -notlike "01-00-5E-*") -and   # IPv4 multicast
                ($_.LinkLayerAddress -notlike "33-33-*")           # IPv6 multicast
            };
        };
        
        
        if ($arpCache) {

            Write-Verbose ("{0}: Parsing results." -f $Computer);
            $OutputArray = @();
            
            foreach ($record in $arpCache) {
             
                $output = $null;
                $output = [ArpCache]::new();
        
                $output.Computer = $Computer;
                $output.DateScanned = Get-Date -Format u;
                
                $output.IfIndex = $record.ifIndex;
                $output.InterfaceAlias = $record.InterfaceAlias;
                $output.IPAdress = $record.IPAddress;
                $output.LinkLayerAddress = $record.LinkLayerAddress;
                $output.State = $record.State;
                $output.PolicyStore = $record.Store;                 

                $OutputArray += $output;
            };

            $total = $total+1;
            return $OutputArray;

        }
        else {
            
            Write-Verbose ("{0}: System failed." -f $Computer);
            if ($Fails) {
                
                $total++;
                Add-Content -Path $Fails -Value ("$Computer");
            }
            else {
                
                $output = $null;
                $output = [ArpCache]::new();

                $output.Computer = $Computer;
                $output.DateScanned = Get-Date -Format u;
                
                $total++;
                return $output;
            };
        };
    };

    end {

        $elapsed = $stopwatch.Elapsed;

        Write-Verbose ("Total Systems: {0} `t Total time elapsed: {1}" -f $total, $elapsed);
    };
};