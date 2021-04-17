#!/bin/bash
#
#     Program: Gerbomber
#     Author:  Gerbil (@M_C_Stott)
#     Version: 1.0   10/04/2020
#     
#     Gerbomber is a clone of Bomber, or whatever the game is called. 
#     The aim is to destroy the buildings by dropping bombs on them,
#     and clear each screen to advance to the next level.
#     
#     Drop the minimum amount of bombs to clear a level to get a "PERFECT".
#
#     This game isn't perfect, it is another game that was written whilst
#     travelling on a four hour motorway trip, so the techiniques used may not
#     be the best but they do work.
#
#     Terminal window must be 80x24 which is default in most cases.
#
#     In game keys are:
#        <space> : Drop bomb
#              p : Pause game               
#              q : Quit game
#
#     From the menu screen:                
#              x : Exit Gerbomber      
#
#     Enjoy the game.
#

trap "stty echo" EXIT  #Turns on local echo if script is exited/ended.
stty -echo #Turns off local echo so key press control chars aren't seen.

CONTROL_LIMIT=0.03   #Delay to accept key press. Acts as speed. The smaller the number, the faster the game.
PLAYFIELD_WIDTH=80 #default term width
PLAYFIELD_HEIGHT=22 #default term height

MAXBUILDINGS=20 #Constants - these do not change
MAXHEIGHT=20
MAXBUILDINGWIDTH=5
MINBUILDINGWIDTH=1


PLANEX=0 #Plane position
PLANEY=2

BOMBX=0 #Bomb positions
BOMBY=0
BOMBFLAG=0

NEWLEVELFLAG=0 #flag to set up new level

BOMBSDROPPED=0 #Count of drops per level

BUILDINGWIDTH=5 #These change through the levels
BUILDINGS=2
BUILDINGHEIGHT=10

BUILDINGCOUNT=0
LIVES=3
SCORE=0
LEVEL=1

declare -A playfield=() # the 'container' of shapes
declare -A buildinglocs=()
declare -A crumbleanim=()

INPLAYFLAG=0

RED="\033[1;31m"
BLUE="\033[0;34m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
BLANK="\033[0m"

updatestats(){
   status=$1
   val=$2
   
   case "${status}" in
#      'LIVES') xPos=15;; #these will change with new level, therefore not needed
#      'LEVEL') xPos=30;;
      'BUILDINGS') xPos=49;;
      'SCORE') xPos=64;;
   esac

   echo -ne "\033[1;${xPos}H${val}  "
   echo -ne "\033[23;0H" #reposition cursor to bottom of playfield 
}

setupplayfield(){
   [[ ${INPLAYFLAG} -eq 0 ]] && { #Check if a brand new game
      LIVES=3
      INPLAYFLAG=1
      LEVEL=1
      SCORE=0
   }
      
   buildings=$1
   buildingheight=$2
   buildingwidth=$3
   BUILDINGCOUNT=${buildings}
   buildinglocs=()
   BOMBSDROPPED=0;  
   PLANEX=0
   PLANEY=2
   
   #Don't break limits - the crap way! :)
   [[ ${buildings} -gt ${MAXBUILDINGS} ]] && buildings=${MAXBUILDINGS}
   [[ ${buildingheight} -gt ${MAXHEIGHT} ]] && buildingheight=${MAXHEIGHT}

   SPACING=$(( 1+ (PLAYFIELD_WIDTH-(buildings * MAXBUILDINGWIDTH))/(buildings+1) ))

   #clear playfield
   for y in $( seq 0 $((PLAYFIELD_HEIGHT-1)) )
   do
      for x in $( seq 0 $((PLAYFIELD_WIDTH-1)) )
      do
         playfield[${x},${y}]=0
      done
   done

   #Setup building positions. 
   bpos=${SPACING}
   for i in $( seq 1 $((buildings)) )
   do
      height=$((1 + RANDOM % buildingheight)) #height goes in reverse due to 0,0 being top-left
      height=$((PLAYFIELD_HEIGHT - height )) #height goes in reverse due to 0,0 being top-left
      width=$(shuf -i ${buildingwidth}-${MAXBUILDINGWIDTH} -n 1)
      for jw in $( seq ${bpos} $((${bpos} + ${width})) ) #building width
      do
         buildinglocs[${jw}]=${i} #ID each column to each building to destroy full building rather than single 'column'
         
         for jh in $( seq ${height} ${PLAYFIELD_HEIGHT}) #building height
         do
            playfield[${jw},${jh}]=${width} #set to colour of width
         done
      done
      bpos=$(( SPACING + ${bpos} + ${width} ))
   done
   printplayfield
}

crumble(){
   frames="▓▓▒▒░░ "

   for i in "${!crumbleanim[@]}"
   do
      posX=${i%%,*} #everything BEFORE the ','
      posY=${i#*,} #everything AFTER the ','
      frame=${crumbleanim[${i}]}
      ((crumbleanim[${i}]++)) #advance the frame

      [[ ${frame} -eq 1 && ${posY} -lt ${PLAYFIELD_HEIGHT} ]] && { #add another vertical "dissolver" below current block.
         crumbleanim[${posX},$((${posY}+1))]=0
      }

      [[ ${frame} -gt ${#frames} ]] && { #remove from array once last frame has been displayed
         unset crumbleanim[${i}]
      }

      echo -ne "\033[${posY};${posX}H${frames:${frame}:1}"
      echo -ne "\033[23;0H" #reposition cursor to bottom of playfield 
   done
}

moveplane(){
   [[ ${PLANEX} -ge ${PLAYFIELD_WIDTH} ]] && {
      ((PLANEY++))
      ((PLANEX=0))
   }
   ((PLANEX++))
   echo -ne "\033[${PLANEY};${PLANEX}H" #reposition cursor  
   printf "\033[0;39m ╘═►\033[0m"

   [[ ${playfield[$((${PLANEX}+3)),$((${PLANEY}-1))]} -gt 0 ]] && { #check for crash
      echo -ne "\033[${PLANEY};${PLANEX}H" #reposition cursor  
      printf "\033[1;31m ***\033[0m"

      printmessage 33 10 " LIFE LOST "
      PLANEX=0
      PLANEY=2
      ((LIVES--))
      printplayfield
      [[ ${LIVES} -lt 1 ]] && {
         printmessage 33 10 " GAME OVER "
         INPLAYFLAG=0
         printtitle 1 1
      }
   }  
   echo -ne "\033[23;0H" #reposition cursor to bottom of playfield    
}   

newlevel(){
   [[ ${BUILDINGS} -eq ${BOMBSDROPPED} ]] && mesg=" PERFECT!! " && ((SCORE+=200))  ||  mesg=" Nice one! " && ((SCORE+=50))
   updatestats SCORE ${SCORE}
   printmessage 33 10 "${mesg}"
   ((LEVEL++))
   ! ((LEVEL % 2)) && ((BUILDINGS++)) || ((BUILDINGHEIGHT++)) && ((BUILDINGWIDTH--))
   [[ ${BUILDINGWIDTH} -lt ${MINBUILDINGWIDTH} ]] && BUILDINGWIDTH=${MINBUILDINGWIDTH}
   setupplayfield ${BUILDINGS} ${BUILDINGHEIGHT} ${BUILDINGWIDTH} 
}
   
movebomb(){
   ((BOMBY++))

   echo -ne "\033[$((${BOMBY}-1));${BOMBX}H" #reposition cursor  
   printf "\033[0;39m \033[0m"
   echo -ne "\033[${BOMBY};${BOMBX}H" #reposition cursor  
   printf "\033[0;39mö\033[0m"

   [[ ${playfield[$((${BOMBX}-1)),$((${BOMBY}-1))]} -gt 0 ]] && { # We've hit a building!
      BOMBFLAG=0
      destroybuilding ${BOMBX}
      [[ ${BUILDINGCOUNT} -le 0 ]] && { #Level completed
         NEWLEVELFLAG=1           
      }
   }
   
   [[ ${BOMBY} -ge ${PLAYFIELD_HEIGHT} ]] && { #when bottom has been reached
      BOMBFLAG=0
      echo -ne "\033[${BOMBY};${BOMBX}H" #reposition cursor  
      printf "\033[0;39m \033[0m"

   }
   echo -ne "\033[23;0H" #reposition cursor to bottom of playfield       
}

destroybuilding(){
   buildingID=${buildinglocs[$(($1-1))]}
   echo -ne "\033[23;0H" #reposition cursor to bottom of playfield  
   colID=${buildingID}
   width=$( grep -o ${colID} <<< ${buildinglocs[*]} | wc -l )
   
   for i in "${!buildinglocs[@]}" #find left hand column (first occurrence) of building
   do
      [[ ${buildinglocs[${i}]} -eq ${colID} ]] && {
      
         #Remove whole vertical "band" from playfield containing building as I'm too lazy to remove just the building
         for j in $( seq 0 ${PLAYFIELD_HEIGHT} ) 
         do
            playfield[${i},${j}]=0
         done
         crumbleanim[$((${i}+1)),${BOMBY}]=0 # Add crumble animation
      }
   done
   
   ((BUILDINGCOUNT--))
   updatestats BUILDINGS ${BUILDINGCOUNT}
   
   case ${width} in
      1) ((SCORE+=100));;
      2) ((SCORE+=50));;
      3) ((SCORE+=25));;
      *) ((SCORE+=10));;
   esac
   updatestats SCORE ${SCORE}
}

printmessage(){
   posX=$1
   posY=$2
   message=$3
   len=$((${#message}+2))
   echo -ne "\033[${posY};${posX}H$( eval printf '*%.0s' {1..${len}} )"
   echo -ne "\033[$((${posY}+1));${posX}H*${message}*"
   echo -ne "\033[$((${posY}+2));${posX}H$( eval printf '*%.0s' {1..${len}} )"
   echo -ne "\033[$((${posY}+3));${posX}Hpress any key"
   echo -ne "\033[23;0H" #reposition cursor to bottom of playfield
   read -sN1 key
}

printtitle(){
   posX=$1
   posY=$2

   echo -ne "\033[$((${posY}));$((${posX}))H                           ${CYAN}██${BLANK}                   ${BLUE}-=CONTROLS=-                    ${BLANK}"                                       
   echo -ne "\033[$((${posY}+1));$((${posX}))H                    ${BLUE}██      ${CYAN}███${BLUE}██${BLANK}            ${BLUE}<space>${CYAN} : Drop bomb                ${BLANK}"                                          
   echo -ne "\033[$((${posY}+2));$((${posX}))H                     ${BLUE}██████████████${BLANK}                ${BLUE}p${CYAN} : Pause game               ${BLANK}"                                                   
   echo -ne "\033[$((${posY}+3));$((${posX}))H                            ${BLUE}██${BLANK}                     ${BLUE}q${CYAN} : Quit game                ${BLANK}"                                        
   echo -ne "\033[$((${posY}+4));$((${posX}))H                          ${BLUE}███${BLANK}                      ${BLUE}x${CYAN} : Exit Gerbomber           ${BLANK}"                                        
   echo -ne "\033[$((${posY}+5));$((${posX}))H                                         ${CYAN}-=Choose speed (${BLUE}1${CYAN}-${BLUE}5${CYAN}) to start=-${BLANK}"                                       
   echo -ne "\033[$((${posY}+6));$((${posX}))H${YELLOW}  ▄████ ▓█████  ██▀███   ▄▄▄▄    ▒█████   ███▄ ▄███▓ ▄▄▄▄   ▓█████  ██▀███      ${BLANK}"
   echo -ne "\033[$((${posY}+7));$((${posX}))H${YELLOW} ██▒ ▀█▒▓█   ▀ ▓██ ▒ ██▒▓█████▄ ▒██▒  ██▒▓██▒▀█▀ ██▒▓█████▄ ▓█   ▀ ▓██ ▒ ██▒    ${BLANK}"
   echo -ne "\033[$((${posY}+8));$((${posX}))H${YELLOW}▒██░▄▄▄░▒███   ▓██ ░▄█ ▒▒██▒ ▄██▒██░  ██▒▓██    ▓██░▒██▒ ▄██▒███   ▓██ ░▄█ ▒    ${BLANK}"
   echo -ne "\033[$((${posY}+9));$((${posX}))H${GREEN}░▓█  ██▓▒▓█  ▄ ▒██▀▀█▄  ▒██░█▀  ▒██   ██░▒██    ▒██ ▒██░█▀  ▒▓█  ▄ ▒██▀▀█▄      ${BLANK}"  
   echo -ne "\033[$((${posY}+10));$((${posX}))H${GREEN}░▒▓███▀▒░▒████▒░██▓ ▒██▒░▓█  ▀█▓░ ████▓▒░▒██▒   ░██▒░▓█  ▀█▓░▒████▒░██▓ ▒██▒    ${BLANK}"
   echo -ne "\033[$((${posY}+11));$((${posX}))H${GREEN} ░▒   ▒ ░░ ▒░ ░░ ▒▓ ░▒▓░░▒▓███▀▒░ ▒░▒░▒░ ░ ▒░   ░  ░░▒▓███▀▒░░ ▒░ ░░ ▒▓ ░▒▓░    ${BLANK}"
   echo -ne "\033[$((${posY}+12));$((${posX}))H${GREEN}  ░   ░  ░ ░  ░  ░▒ ░ ▒░▒░▒   ░   ░ ▒ ▒░ ░  ░      ░▒░▒   ░  ░ ░  ░  ░▒ ░     ▒░    ${BLANK}"
   echo -ne "\033[$((${posY}+13));$((${posX}))H${GREEN}░ ░   ░    ░     ░░   ░  ░    ░ ░ ░ ░ ▒  ░      ░    ░    ░    ░     ░░   ░     ${BLANK}"
   echo -ne "\033[$((${posY}+14));$((${posX}))H${GREEN}      ░    ░  ░   ░      ░          ░ ░         ░    ░         ░  ░   ░         ${BLANK}"
   echo -ne "\033[$((${posY}+15));$((${posX}))H  ${CYAN}Bomber written in bash.${BLANK}     ${GREEN}░                           ░                     ${BLANK}"
   echo -ne "\033[$((${posY}+16));$((${posX}))H  ${CYAN}Coded by: @M_C_Stott (aka Gerbil)${BLANK}  ███████     █                              "
   echo -ne "\033[$((${posY}+17));$((${posX}))H                                     █ █ █ █     █          ███████             "              
   echo -ne "\033[$((${posY}+18));$((${posX}))H       █            ${RED}█${BLANK}                ███████   ▓▓███        █     █             "              
   echo -ne "\033[$((${posY}+19));$((${posX}))H           ${RED}█     █${BLANK}                   █ █ █ █  ▓▓█████       █ █ █ █             "               
   echo -ne "\033[$((${posY}+20));$((${posX}))H     █ ${RED}█ █  █${BLANK}        █               ███████  ▓ █   █     ▒▒█     █▒▒▒▒▒▒▒      "                   
   echo -ne "\033[$((${posY}+21));$((${posX}))H         ███${RED}██${BLANK} █    ${RED} █${BLANK}               █ █ █ █  ▓ █ █ █     ▒ █ █ █ █      ▒      "             
   echo -ne "\033[$((${posY}+22));$((${posX}))H     ${RED}█${BLANK}   █ █ █ █  █ █                ███████  ▓ █   █     ▒▒█     █▒▒▒▒▒▒▒      "             
   echo -ne "\033[$((${posY}+23));$((${posX}))H         ███████ █                   █ █ █ █  ▓ █ █ █     ▒ █ █ █ █      ▒      "        
while :
do
   read -sN1 key
   case "${key}" in
   [1-5]) CONTROL_LIMIT=0.0$((5-${key}+1)); break;;
   esac
   [[ "${key^}" == 'X' ]] && echo "BYE BYE PEEPS!" && exit
done
}

printplayfield(){
   echo -ne "\033[2J" #clear screen and reset cursor to 0,0   
   for y in $( seq 0 $((${PLAYFIELD_HEIGHT}-1)) ) 
   do         
      for x in $( seq 0 $((${PLAYFIELD_WIDTH}-1)) )
      do    
         block=${playfield[${x},${y}]}
         if [ ${block} -gt 0 ]
         then
            echo -ne "\033[$((${y}+1));$((${x}+1))H" #reposition cursor  
            printf "\033[0;3${block}m█\033[0m" 
         fi
      done
   done;
   echo -ne "\033[0;0H" #reposition cursor to 0,0
   echo -ne "       LIVES: ${LIVES}       LEVEL: ${LEVEL}       BUILDINGS: ${BUILDINGCOUNT}       SCORE: ${SCORE}"
   echo -ne "\033[23;0H" #reposition cursor to bottom of playfield   
}

#################################################################
# Setup game.

echo -ne "\033[2J" #clear screen and reset cursor to 0,0

while :  # 1 char (not delimiter), silent
do
   [[ ${INPLAYFLAG} -eq 0 ]] && { #Reset a brand new game
      printtitle 1 1
      BUILDINGWIDTH=5
      BUILDINGS=5
      BUILDINGHEIGHT=12
      BUILDINGCOUNT=5      

      setupplayfield ${BUILDINGS} ${BUILDINGHEIGHT} ${BUILDINGWIDTH}  #setupplayfield <buildings> <maxheight> <maxwidth>
   }
   #read keystroke:
   read -sN1 -t ${CONTROL_LIMIT} key 

   # catch multi-char special key sequences
   read -sN1 -t 0.0001 k1
   read -sN1 -t 0.0001 k2
   read -sN1 -t 0.0001 k3
   key+=${k1}${k2}${k3}

   case "$key" in
      ' ')  # drop bomb
      [[ ${BOMBFLAG} -eq 0 ]] && {
         ((BOMBFLAG++))
         BOMBX=$((${PLANEX}+2))
         BOMBY=${PLANEY}
         ((BOMBSDROPPED++))
      };;
      [pP]) #pause game
      printmessage 33 10 "P A U S E D"
      printplayfield;;
      q) # q, carriage return: quit
      INPLAYFLAG=0
      BOMBFLAG=0;;
   esac
   moveplane
   [[ ${BOMBFLAG} -eq 1 ]] && movebomb
   crumble
   [[ NEWLEVELFLAG -eq 1 && ${#crumbleanim[@]} -le 0 ]] && {
      NEWLEVELFLAG=0
      newlevel
   }   
done

