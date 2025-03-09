package core

import (
	"fmt"
	"strings"

	"github.com/fatih/color"
)

const (
	VERSION = "3.3.0"
)

func putAsciiArt(s string) {
	for _, c := range s {
		d := string(c)
		switch string(c) {
		case " ":
			color.Set(color.BgRed)
			d = " "
		case "@":
			color.Set(color.BgBlack)
			d = " "
		case "#":
			color.Set(color.BgHiRed)
			d = " "
		case "W":
			color.Set(color.BgWhite)
			d = " "
		case "_":
			color.Unset()
			d = " "
		case "\n":
			color.Unset()
		}
		fmt.Print(d)
	}
	color.Unset()
}

func printLogo(s string) {
	for _, c := range s {
		d := string(c)
		switch string(c) {
		case "_":
			color.Set(color.FgWhite)
		case "\n":
			color.Unset()
		default:
			color.Set(color.FgHiBlack)
		}
		fmt.Print(d)
	}
	color.Unset()
}

func printUpdateName() {
	nameClr := color.New(color.FgHiWhite)
	txt := nameClr.Sprintf("               - --  MDR Mod  -- -")
	fmt.Fprintf(color.Output, "%s", txt)
}

func printOneliner1() {
	handleClr := color.New(color.FgHiBlue)
	versionClr := color.New(color.FgGreen)
	textClr := color.New(color.FgHiBlack)
	spc := strings.Repeat(" ", 10-len(VERSION))
	txt := textClr.Sprintf("      by Evolcorp MDR (") + handleClr.Sprintf("@martybyrde007") + textClr.Sprintf(")") + spc + textClr.Sprintf("version ") + versionClr.Sprintf("%s", VERSION)
	fmt.Fprintf(color.Output, "%s", txt)
}

func printOneliner2() {
	textClr := color.New(color.FgHiBlack)
	red := color.New(color.FgRed)
	white := color.New(color.FgWhite)
	txt := textClr.Sprintf("                   no ") + red.Sprintf("nginx") + white.Sprintf(" - ") + textClr.Sprintf("pure ") + red.Sprintf("evil")
	fmt.Fprintf(color.Output, "%s", txt)
}

func Banner() {
	fmt.Println()

	putAsciiArt("__                                     __\n")
	putAsciiArt("_   @@     @@@@@@@@@@@@@@@@@@@     @@   _")
	printLogo(`    ╔╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╗	`)
	fmt.Println()
	putAsciiArt("  @@@@    @@@@@@@@@@@@@@@@@@@@@    @@@@  ")
	printLogo(`    ╠╬╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╬╣	`)
	fmt.Println()
	putAsciiArt("  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  ")
	printLogo(`    ╠╣.....................................................................╠╣	`)
	fmt.Println()
	putAsciiArt("    @@@@@@@@@@###@@@@@@@###@@@@@@@@@@    ")
	printLogo(`    ╠╣.███████╗██╗...██╗.██████╗.██╗......██████╗.██████╗.██████╗.██████╗..╠╣	`)
	fmt.Println()
	putAsciiArt("      @@@@@@@#####@@@@@#####@@@@@@@      ")
	printLogo(`    ╠╣.██╔════╝██║...██║██╔═══██╗██║.....██╔════╝██╔═══██╗██╔══██╗██╔══██╗.╠╣	`)
	fmt.Println()
	putAsciiArt("       @@@@@@@###@@@@@@@###@@@@@@@       ")
	printLogo(`    ╠╣.█████╗..██║...██║██║...██║██║.....██║.....██║...██║██████╔╝██████╔╝.╠╣	`)
	fmt.Println()
	putAsciiArt("      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@      ")
	printLogo(`    ╠╣.██╔══╝..╚██╗.██╔╝██║...██║██║.....██║.....██║...██║██╔══██╗██╔═══╝..╠╣	`)
	fmt.Println()
	putAsciiArt("     @@@@@WW@@@WW@@WWW@@WW@@@WW@@@@@     ")
	printLogo(`    ╠╣.███████╗.╚████╔╝.╚██████╔╝███████╗╚██████╗╚██████╔╝██║..██║██║......╠╣	`)
	fmt.Println()
	putAsciiArt("    @@@@@@WW@@@WW@@WWW@@WW@@@WW@@@@@@    ")
	printLogo(`    ╠╣.╚══════╝..╚═══╝...╚═════╝.╚══════╝.╚═════╝.╚═════╝.╚═╝..╚═╝╚═╝......╠╣	`)
	fmt.Println()
	putAsciiArt("   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   ")
	printLogo(`    ╠╣.....................................................................╠╣	`)
	fmt.Println()
	putAsciiArt("  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  ")
	printLogo(`    ╠╬╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╦╬╣	`)
	fmt.Println()
	putAsciiArt("_   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   _")
	printLogo(`    ╚╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩╝	`)
	fmt.Println()
	putAsciiArt("__                                     __\n")
	fmt.Println()

	printUpdateName()
	fmt.Println()
	// putAsciiArt("    @@@@@@WW@@@WW@@WWW@@WW@@@WW@@@@@@    \n")
	//printOneliner2()
	//fmt.Println()
	// putAsciiArt("_   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@   _")
	printOneliner1()
	fmt.Println()
	// putAsciiArt("__                                     __\n")
	fmt.Println()
}

