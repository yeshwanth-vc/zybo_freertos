DMI Read/Write 
Purpose:
The single_DMI_rd_wr.c tool allows control of the SiFive E21 debug module using DMI commands (reset, activate, halt, resume, reg/mem/csr access).

Compilation:
To compile the program, use:
     gcc -o single_DMI_rd_wr single_DMI_rd_wr.c 
This generates an executable named single_DMI_rd_wr.
	
Usage:
Once compiled, the program can be executed with the appropriate parameters.Run the compiled executable with necessary permissions:
	./single_DMI_rd_wr <operation> [args...]

Supported Operations:
	Operation Name	Code	Parameters
	Reset DMI	0	—
	Activate DM	1	—
	Halt		2	—
	Resume		3	—
	Step		4	—
	Read Reg	5	<regno>
	Write Reg	6	<regno> <data>
	Read CSR	7	<csrno>
	Write CSR	8	<csrno> <data>
	Read Mem	9	<addr>
	Write Mem	10	<addr> <data>

Example:
	./single_DMI_rd_wr 9 0x80000000
	Write 0x1234abcd to memory at 0x80000000:

Error Handling:
If you face permission issues:
 	sudo ./single_DMI_rd_wr <args...>

Reference
*RISC-V Debug Specification, Chapter 3: Debug Module (DM)
*Contains details on registers, state machine, and DMI operation and other implementation sequences.
