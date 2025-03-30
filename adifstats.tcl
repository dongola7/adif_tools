#!/usr/bin/tclsh

# Copyright (c) 2025, Blair Kitchen
# All rights resetved.
#
# See the file "license.terms" for informatio on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
# Script to print some contest related statistics from an ADIF file. Purpose
# is to help with scoring Amateur Radio Contests
#
package require Tcl 8.5
package require cmdline 1.3

source adif.tcl
package require adif 0.1

proc main {argc argv} {
    set options {
        {output.arg "" "name of the output file. stdout if ommitted"}
    }
    set usage ": adifstats.tcl \[options] file1 file2 ... \noptions:"
    if {[catch {array set params [::cmdline::getoptions argv $options $usage]} result]} {
        puts $result
        exit -1
    }

    set outChan stdout
    if {$params(output) != ""} {
        set outChan [open $params(output) "w"]
    }

    # Process each input file in order
    foreach inputFile [::cmdline::getfiles $argv false] {
        set inChan [open $inputFile "r"]

        # Initialize storage dicts
        set continentDict [dict create]

        # An empty dict indicates we've reached EOF
        set adifRecord [::adif::readNextRecord $inChan]
        while {[dict size $adifRecord] != 0} {

            # We're only processing qso records. Skip everything else
            if {[dict get $adifRecord recordType] == "qso"} {
                set recordFields [dict get $adifRecord recordData]
                
                aggregateContinentStats continentDict $recordFields

            }

            set adifRecord [::adif::readNextRecord $inChan]
        }

        printContinentStats $continentDict $outChan

        close $inChan
    }
}

#
# Given a dictionary variable to store aggregate results and an adif record,
# aggregates all of the continent and country QSOs for output by the
# printContinentStats function.
#
# This function uses the following adif fields:
#    DXCC - Used to determine the country
#    CONT - Used to determine the continent
#    FREQ - Used to determine the band
#
# If either the DXCC or CONT fields are missing, the QSO will be aggregated
# in the appropriate UNKNOWN bucket.
#
proc aggregateContinentStats {continentDictVar recordFields} {
    upvar $continentDictVar continentDict

    set continent "UNKNOWN"
    if {[dict exists $recordFields cont]} {
        set continent [dict get $recordFields cont]
    }
    set continent [contToContinent $continent]

    set dxcc "UNKNOWN"
    if {[dict exists $recordFields dxcc]} {
        set dxcc [dict get $recordFields dxcc]
    }
    set dxcc [dxccToCountry $dxcc]

    set band [freqToBand [dict get $recordFields freq]]

    # Increment the country level count
    set count 1
    if {[dict exists $continentDict $continent countries $dxcc $band]} {
        set count [dict get $continentDict $continent countries $dxcc $band]
        incr count
    }
    dict set continentDict $continent countries $dxcc $band $count

    # Increment the continent level count
    set count 1
    if {[dict exists $continentDict $continent summary $band]} {
        set count [dict get $continentDict $continent summary $band]
        incr count
    }
    dict set continentDict $continent summary $band $count
}

#
# Given a dictionary populated by the aggregateContinentStats function, formats
# and prints the aggregate statistics to the provided outChan.
#
# Sample output:
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# North America                      0  0  0  25   0   5   0   0   0   0   0   0    0
#
#   United States of America         0  0  0  25   0   0   0   0   0   0   0   0    0
#   Canada                           0  0  0   0   0   5   0   0   0   0   0   0    0
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# Europe                             0  0  0  10   0   4   0   0   0   0   0   0    0
#
#   Spain                            0  0  0   5   0   1   0   0   0   0   0   0    0
#   France                           0  0  0   4   0   3   0   0   0   0   0   0    0
#   UNKNOWN                          0  0  0   1   0   0   0   0   0   0   0   0    0
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# UNKNOWN                            0  0  0   0   1   1   0   0   0   0   0   0    0
#
#   Belgium                          0  0  0   0   1   0   0   0   0   0   0   0    0
#   UNKNOWN                          0  0  0   0   0   1   0   0   0   0   0   0    0
#
#                                 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m
# Totals                             0  0  0  35   1  10   0   0   0   0   0   0    0
#
proc printContinentStats {continentDict outChan} {

    # Width of the band columns
    set bandWidth 6
    # Width of the first column showing continents
    set continentWidth 45
    # Width of the country columns
    set countryPrefixWidth 4
    set countryWidth [expr {$continentWidth - $countryPrefixWidth}]

    # Generate the band header based on the list of bands being summarized
    set bandList [list 70cm 2m 6m 10m 12m 15m 17m 20m 30m 40m 60m 80m 160m]
    set bandHeader [format "% ${continentWidth}s" ""]
    foreach band $bandList {
        append bandHeader [format "% ${bandWidth}s " $band]
    }

    # Used to track the total number of QSOs in each band
    set bandTotals [dict create]
    foreach band $bandList {
        dict set bandTotals $band 0
    }

    # Iterate across the continents
    dict for {continent continentValues} $continentDict {

        # Build the continent level summary line
        puts $outChan $bandHeader
        set summaryLine [format "%-${continentWidth}s" $continent]
        foreach band $bandList {
            set count 0
            if {[dict exists $continentValues summary $band]} {
                set count [dict get $continentValues summary $band]
            }
            append summaryLine [format "%${bandWidth}d " $count]
        }
        puts $outChan $summaryLine
        puts $outChan ""


        # Iterate across the countries in each continent
        dict for {country countryValues} [dict get $continentValues countries] {

            # Build the country level summary line
            set countryLine [format "%${countryPrefixWidth}s%-${countryWidth}s" "" $country]
            foreach band $bandList {
                set count 0
                if {[dict exists $countryValues $band]} {
                    set count [dict get $countryValues $band]
                }
                append countryLine [format "%${bandWidth}d " $count]

                # Track the running total for each band
                dict incr bandTotals $band $count
            }
            puts $outChan $countryLine
        }

        puts $outChan ""
    }

    # Output the total QSOs per band
    puts $outChan $bandHeader
    set summaryLine [format "%-${continentWidth}s" "Totals"]
    foreach band $bandList {
        append summaryLine [format "%${bandWidth}d " [dict get $bandTotals $band]]
    }
    puts $outChan $summaryLine
}

#
# Given an ADIF Continent enumeration from the CONT field, returns
# the full continent name. Returns **UNKNOWN** if the enumeration is
# not recognized. This function is not case sensitive.
#
proc contToContinent {cont} {
    set cont [string tolower $cont]
    if {$cont == "na"} {
        return "NORTH AMERICA"
    } elseif {$cont == "sa"} {
        return "SOUTH AMERICA"
    } elseif {$cont == "eu" } {
        return "EUROPE"
    } elseif {$cont == "af"} {
        return "AFRICA"
    } elseif {$cont == "oc"} {
        return "OCEANIA"
    } elseif {$cont == "as"} {
        return "ASIA"
    } elseif {$cont == "an"} {
        return "ANTARCTICA"
    } else {
        return "**UNKNOWN**"
    }
}

#
# Given an ADIF DXCC enumeration fro the DXCC field, returns
# the associated country name. Returns **UNKNOWN** if the enumeration
# is not recognized.
#
proc dxccToCountry {dxcc} {
    if {[info exists ::dxcc2Country($dxcc)]} {
        return $::dxcc2Country($dxcc)
    } else {
        return "**UNKNOWN**"
    }
}

#
# Given a frequency in MHz, returns the corresponding band (70cm, 10m, 17m, etc)
# Returns UNKNOWN if the frequency does not map to a known band.
#
proc freqToBand {freq} {
    # Frequency -> band mappings taken from ARRL band plan
    if {$freq >= 420 && $freq <= 450} {
        # 70cm 420MHz - 450MHz
        return "70cm"
    } elseif {$freq >= 144 && $freq <= 148} {
        # 2m   144MHz - 148MHz
        return "2m"
    } elseif {$freq >= 50 && $freq <= 54} {
        # 6m   50MHz - 54MHz
        return "6m"
    } elseif {$freq >= 28 && $freq <= 29.7} {
        # 10m  28MHz - 29.7MHz
        return "10m"
    } elseif {$freq >= 24.89 && $freq <= 24.99} {
        # 12m  24.890MHz - 24.990MHz
        return "12m"
    } elseif {$freq >= 21 && $freq <= 21.45} {
        # 15m  21.000MHz - 21.450MHz
        return "15m"
    } elseif {$freq >= 18.068 && $freq <= 18.168} {
        # 17m  18.068MHz - 18.168MHz
        return "17m"
    } elseif {$freq >= 14 && $freq <= 14.35} {
        # 20m  14.000MHz - 14.350MHz
        return "20m"
    } elseif {$freq >= 10.1 && $freq <= 10.15} {
        # 30m  10.100MHz - 10,150MHz
        return "30m"
    } elseif {$freq >= 7 && $freq <= 7.3} {
        # 40m   7.000MHz - 7.300MHz
        return "40m"
    } elseif {$freq >= 3.5 && $freq <= 4} {
        # 80m   3.500MHz - 4.000MHz
        return  "80m"
    } elseif {$freq >= 1.8 && $freq <= 2} {
        # 160m  1.800MHz - 2.000MHz
        return "160m"
    } else {
        return "UNKNOWN"
    }
}

array set ::dxcc2Country {
    0	"NONE"
    1	"CANADA"
    2	"ABU AIL IS."
    3	"AFGHANISTAN"
    4	"AGALEGA & ST. BRANDON IS."
    5	"ALAND IS."
    6	"ALASKA"
    7	"ALBANIA"
    8	"ALDABRA"
    9	"AMERICAN SAMOA"
    10	"AMSTERDAM & ST. PAUL IS."
    11	"ANDAMAN & NICOBAR IS."
    12	"ANGUILLA"
    13	"ANTARCTICA"
    14	"ARMENIA"
    15	"ASIATIC RUSSIA"
    16	"NEW ZEALAND SUBANTARCTIC ISLANDS"
    17	"AVES I."
    18	"AZERBAIJAN"
    19	"BAJO NUEVO"
    20	"BAKER & HOWLAND IS."
    21	"BALEARIC IS."
    22	"PALAU"
    23	"BLENHEIM REEF"
    24	"BOUVET"
    25	"BRITISH NORTH BORNEO"
    26	"BRITISH SOMALILAND"
    27	"BELARUS"
    28	"CANAL ZONE"
    29	"CANARY IS."
    30	"CELEBE & MOLUCCA IS."
    31	"C. KIRIBATI (BRITISH PHOENIX IS.)"
    32	"CEUTA & MELILLA"
    33	"CHAGOS IS."
    34	"CHATHAM IS."
    35	"CHRISTMAS I."
    36	"CLIPPERTON I."
    37	"COCOS I."
    38	"COCOS (KEELING) IS."
    39	"COMOROS"
    40	"CRETE"
    41	"CROZET I."
    42	"DAMAO, DIU"
    43	"DESECHEO I."
    44	"DESROCHES"
    45	"DODECANESE"
    46	"EAST MALAYSIA"
    47	"EASTER I."
    48	"E. KIRIBATI (LINE IS.)"
    49	"EQUATORIAL GUINEA"
    50	"MEXICO"
    51	"ERITREA"
    52	"ESTONIA"
    53	"ETHIOPIA"
    54	"EUROPEAN RUSSIA"
    55	"FARQUHAR"
    56	"FERNANDO DE NORONHA"
    57	"FRENCH EQUATORIAL AFRICA"
    58	"FRENCH INDO-CHINA"
    59	"FRENCH WEST AFRICA"
    60	"BAHAMAS"
    61	"FRANZ JOSEF LAND"
    62	"BARBADOS"
    63	"FRENCH GUIANA"
    64	"BERMUDA"
    65	"BRITISH VIRGIN IS."
    66	"BELIZE"
    67	"FRENCH INDIA"
    68	"KUWAIT/SAUDI ARABIA NEUTRAL ZONE"
    69	"CAYMAN IS."
    70	"CUBA"
    71	"GALAPAGOS IS."
    72	"DOMINICAN REPUBLIC"
    74	"EL SALVADOR"
    75	"GEORGIA"
    76	"GUATEMALA"
    77	"GRENADA"
    78	"HAITI"
    79	"GUADELOUPE"
    80	"HONDURAS"
    81	"GERMANY"
    82	"JAMAICA"
    84	"MARTINIQUE"
    85	"BONAIRE, CURACAO"
    86	"NICARAGUA"
    88	"PANAMA"
    89	"TURKS & CAICOS IS."
    90	"TRINIDAD & TOBAGO"
    91	"ARUBA"
    93	"GEYSER REEF"
    94	"ANTIGUA & BARBUDA"
    95	"DOMINICA"
    96	"MONTSERRAT"
    97	"ST. LUCIA"
    98	"ST. VINCENT"
    99	"GLORIOSO IS."
    100	"ARGENTINA"
    101	"GOA"
    102	"GOLD COAST, TOGOLAND"
    103	"GUAM"
    104	"BOLIVIA"
    105	"GUANTANAMO BAY"
    106	"GUERNSEY"
    107	"GUINEA"
    108	"BRAZIL"
    109	"GUINEA-BISSAU"
    110	"HAWAII"
    111	"HEARD I."
    112	"CHILE"
    113	"IFNI"
    114	"ISLE OF MAN"
    115	"ITALIAN SOMALILAND"
    116	"COLOMBIA"
    117	"ITU HQ"
    118	"JAN MAYEN"
    119	"JAVA"
    120	"ECUADOR"
    122	"JERSEY"
    123	"JOHNSTON I."
    124	"JUAN DE NOVA, EUROPA"
    125	"JUAN FERNANDEZ IS."
    126	"KALININGRAD"
    127	"KAMARAN IS."
    128	"KARELO-FINNISH REPUBLIC"
    129	"GUYANA"
    130	"KAZAKHSTAN"
    131	"KERGUELEN IS."
    132	"PARAGUAY"
    133	"KERMADEC IS."
    134	"KINGMAN REEF"
    135	"KYRGYZSTAN"
    136	"PERU"
    137	"REPUBLIC OF KOREA"
    138	"KURE I."
    139	"KURIA MURIA I."
    140	"SURINAME"
    141	"FALKLAND IS."
    142	"LAKSHADWEEP IS."
    143	"LAOS"
    144	"URUGUAY"
    145	"LATVIA"
    146	"LITHUANIA"
    147	"LORD HOWE I."
    148	"VENEZUELA"
    149	"AZORES"
    150	"AUSTRALIA"
    151	"MALYJ VYSOTSKIJ I."
    152	"MACAO"
    153	"MACQUARIE I."
    154	"YEMEN ARAB REPUBLIC"
    155	"MALAYA"
    157	"NAURU"
    158	"VANUATU"
    159	"MALDIVES"
    160	"TONGA"
    161	"MALPELO I."
    162	"NEW CALEDONIA"
    163	"PAPUA NEW GUINEA"
    164	"MANCHURIA"
    165	"MAURITIUS"
    166	"MARIANA IS."
    167	"MARKET REEF"
    168	"MARSHALL IS."
    169	"MAYOTTE"
    170	"NEW ZEALAND"
    171	"MELLISH REEF"
    172	"PITCAIRN I."
    173	"MICRONESIA"
    174	"MIDWAY I."
    175	"FRENCH POLYNESIA"
    176	"FIJI"
    177	"MINAMI TORISHIMA"
    178	"MINERVA REEF"
    179	"MOLDOVA"
    180	"MOUNT ATHOS"
    181	"MOZAMBIQUE"
    182	"NAVASSA I."
    183	"NETHERLANDS BORNEO"
    184	"NETHERLANDS NEW GUINEA"
    185	"SOLOMON IS."
    186	"NEWFOUNDLAND, LABRADOR"
    187	"NIGER"
    188	"NIUE"
    189	"NORFOLK I."
    190	"SAMOA"
    191	"NORTH COOK IS."
    192	"OGASAWARA"
    193	"OKINAWA (RYUKYU IS.)"
    194	"OKINO TORI-SHIMA"
    195	"ANNOBON I."
    196	"PALESTINE"
    197	"PALMYRA & JARVIS IS."
    198	"PAPUA TERRITORY"
    199	"PETER 1 I."
    200	"PORTUGUESE TIMOR"
    201	"PRINCE EDWARD & MARION IS."
    202	"PUERTO RICO"
    203	"ANDORRA"
    204	"REVILLAGIGEDO"
    205	"ASCENSION I."
    206	"AUSTRIA"
    207	"RODRIGUES I."
    208	"RUANDA-URUNDI"
    209	"BELGIUM"
    210	"SAAR"
    211	"SABLE I."
    212	"BULGARIA"
    213	"SAINT MARTIN"
    214	"CORSICA"
    215	"CYPRUS"
    216	"SAN ANDRES & PROVIDENCIA"
    217	"SAN FELIX & SAN AMBROSIO"
    218	"CZECHOSLOVAKIA"
    219	"SAO TOME & PRINCIPE"
    220	"SARAWAK"
    221	"DENMARK"
    222	"FAROE IS."
    223	"ENGLAND"
    224	"FINLAND"
    225	"SARDINIA"
    226	"SAUDI ARABIA/IRAQ NEUTRAL ZONE"
    227	"FRANCE"
    228	"SERRANA BANK & RONCADOR CAY"
    229	"GERMAN DEMOCRATIC REPUBLIC"
    230	"FEDERAL REPUBLIC OF GERMANY"
    231	"SIKKIM"
    232	"SOMALIA"
    233	"GIBRALTAR"
    234	"SOUTH COOK IS."
    235	"SOUTH GEORGIA I."
    236	"GREECE"
    237	"GREENLAND"
    238	"SOUTH ORKNEY IS."
    239	"HUNGARY"
    240	"SOUTH SANDWICH IS."
    241	"SOUTH SHETLAND IS."
    242	"ICELAND"
    243	"PEOPLE'S DEMOCRATIC REP. OF YEMEN"
    244	"SOUTHERN SUDAN"
    245	"IRELAND"
    246	"SOVEREIGN MILITARY ORDER OF MALTA"
    247	"SPRATLY IS."
    248	"ITALY"
    249	"ST. KITTS & NEVIS"
    250	"ST. HELENA"
    251	"LIECHTENSTEIN"
    252	"ST. PAUL I."
    253	"ST. PETER & ST. PAUL ROCKS"
    254	"LUXEMBOURG"
    255	"ST. MAARTEN, SABA, ST. EUSTATIUS"
    256	"MADEIRA IS."
    257	"MALTA"
    258	"SUMATRA"
    259	"SVALBARD"
    260	"MONACO"
    261	"SWAN IS."
    262	"TAJIKISTAN"
    263	"NETHERLANDS"
    264	"TANGIER"
    265	"NORTHERN IRELAND"
    266	"NORWAY"
    267	"TERRITORY OF NEW GUINEA"
    268	"TIBET"
    269	"POLAND"
    270	"TOKELAU IS."
    271	"TRIESTE"
    272	"PORTUGAL"
    273	"TRINDADE & MARTIM VAZ IS."
    274	"TRISTAN DA CUNHA & GOUGH I."
    275	"ROMANIA"
    276	"TROMELIN I."
    277	"ST. PIERRE & MIQUELON"
    278	"SAN MARINO"
    279	"SCOTLAND"
    280	"TURKMENISTAN"
    281	"SPAIN"
    282	"TUVALU"
    283	"UK SOVEREIGN BASE AREAS ON CYPRUS"
    284	"SWEDEN"
    285	"VIRGIN IS."
    286	"UGANDA"
    287	"SWITZERLAND"
    288	"UKRAINE"
    289	"UNITED NATIONS HQ"
    291	"UNITED STATES OF AMERICA"
    292	"UZBEKISTAN"
    293	"VIET NAM"
    294	"WALES"
    295	"VATICAN"
    296	"SERBIA"
    297	"WAKE I."
    298	"WALLIS & FUTUNA IS."
    299	"WEST MALAYSIA"
    301	"W. KIRIBATI (GILBERT IS. )"
    302	"WESTERN SAHARA"
    303	"WILLIS I."
    304	"BAHRAIN"
    305	"BANGLADESH"
    306	"BHUTAN"
    307	"ZANZIBAR"
    308	"COSTA RICA"
    309	"MYANMAR"
    312	"CAMBODIA"
    315	"SRI LANKA"
    318	"CHINA"
    321	"HONG KONG"
    324	"INDIA"
    327	"INDONESIA"
    330	"IRAN"
    333	"IRAQ"
    336	"ISRAEL"
    339	"JAPAN"
    342	"JORDAN"
    344	"DEMOCRATIC PEOPLE'S REP. OF KOREA"
    345	"BRUNEI DARUSSALAM"
    348	"KUWAIT"
    354	"LEBANON"
    363	"MONGOLIA"
    369	"NEPAL"
    370	"OMAN"
    372	"PAKISTAN"
    375	"PHILIPPINES"
    376	"QATAR"
    378	"SAUDI ARABIA"
    379	"SEYCHELLES"
    381	"SINGAPORE"
    382	"DJIBOUTI"
    384	"SYRIA"
    386	"TAIWAN"
    387	"THAILAND"
    390	"TURKEY"
    391	"UNITED ARAB EMIRATES"
    400	"ALGERIA"
    401	"ANGOLA"
    402	"BOTSWANA"
    404	"BURUNDI"
    406	"CAMEROON"
    408	"CENTRAL AFRICA"
    409	"CAPE VERDE"
    410	"CHAD"
    411	"COMOROS"
    412	"REPUBLIC OF THE CONGO"
    414	"DEMOCRATIC REPUBLIC OF THE CONGO"
    416	"BENIN"
    420	"GABON"
    422	"THE GAMBIA"
    424	"GHANA"
    428	"COTE D'IVOIRE"
    430	"KENYA"
    432	"LESOTHO"
    434	"LIBERIA"
    436	"LIBYA"
    438	"MADAGASCAR"
    440	"MALAWI"
    442	"MALI"
    444	"MAURITANIA"
    446	"MOROCCO"
    450	"NIGERIA"
    452	"ZIMBABWE"
    453	"REUNION I."
    454	"RWANDA"
    456	"SENEGAL"
    458	"SIERRA LEONE"
    460	"ROTUMA I."
    462	"REPUBLIC OF SOUTH AFRICA"
    464	"NAMIBIA"
    466	"SUDAN"
    468	"KINGDOM OF ESWATINI"
    470	"TANZANIA"
    474	"TUNISIA"
    478	"EGYPT"
    480	"BURKINA FASO"
    482	"ZAMBIA"
    483	"TOGO"
    488	"WALVIS BAY"
    489	"CONWAY REEF"
    490	"BANABA I. (OCEAN I.)"
    492	"YEMEN"
    493	"PENGUIN IS."
    497	"CROATIA"
    499	"SLOVENIA"
    501	"BOSNIA-HERZEGOVINA"
    502	"NORTH MACEDONIA (REPUBLIC OF)"
    503	"CZECH REPUBLIC"
    504	"SLOVAK REPUBLIC"
    505	"PRATAS I."
    506	"SCARBOROUGH REEF"
    507	"TEMOTU PROVINCE"
    508	"AUSTRAL I."
    509	"MARQUESAS IS."
    510	"PALESTINE"
    511	"TIMOR-LESTE"
    512	"CHESTERFIELD IS."
    513	"DUCIE I."
    514	"MONTENEGRO"
    515	"SWAINS I."
    516	"SAINT BARTHELEMY"
    517	"CURACAO"
    518	"SINT MAARTEN"
    519	"SABA & ST. EUSTATIUS"
    520	"BONAIRE"
    521	"SOUTH SUDAN (REPUBLIC OF)"
    522	"REPUBLIC OF KOSOVO"
}

main $argc $argv
