%define SYS_W 4		;sys_write para escribir un archivo preexistente EAX 4 EBX salida ECX cadena EDX largo cadena
%define STD_OUT 1	;Salida estandard por consola
%define SYS_O 5		;sys_open para abrir un archivo EAX 5 EBX path ECX flags EDX modo lectura o escritura
%define READ_ONLY 0	;modo solo lectura
%define WRITE_READ_EX 0777 ;modo lectura, escritura y ejecucion
%define SYS_R 3		;sys_read para leer archivo.EAX 3 EBX descriptor archivo ECX pointer to caracter EDX bytes a leer
%define SYS_C 6		;sys_close cerrar archivo EAX 6 EBX file descriptor
%define SYS_CREAT 8	;sys_create crea un archivo EAX 8

%define SYS_EXIT 1	;para salir EAX 1 EBX int error 0 sin error

%define SIN_ERROR 0
%define ERROR_ARCHIVO 1 ;error en archivo de entrada
%define ERROR_SALIDA 2	;error en archivo de salida
%define ERROR_GENERAL 3 ;error de proposito general

%define salto Ah
%define enter Ch

section .data
	texto_inicio db "Este es un programa escrito en lenguaje ensamblador",10,10 	;Texto y dos saltos de linea
	largo_inicio equ $ - texto_inicio						;aqui largo se utiliza para guardar la pos del puntero
	texto_salida db "El programa finalizo correctamente",10				;Texto de salida sin error
	largo_salida equ $ - texto_salida
	texto_error db "El programa finalizo con errores",10
	largo_error equ $ - texto_error	
	texto_error_entrada db "No se encontro el archivo o es invalido",10
	largo_error_entrada equ $ - texto_error_entrada
	texto_exceso_parametros db "Hay mas de dos parametros.",10
	largo_exceso_parametros equ $ - texto_exceso_parametros
	texto_ayuda db "Este es el texto de ayuda",10
	largo_ayuda equ $ - texto_ayuda
	texto_ayuda_error db "Use la opcion -h para recibir ayuda",10
	largo_ayuda_error equ $ - texto_ayuda_error
	texto_error_ofile db "No se pudo abrir el archivo",10
	largo_error_ofile equ $ - texto_error_ofile
	texto_error_rfile db "No se pudo leer el archivo",10
	largo_error_rfile equ $ - texto_error_rfile
	texto_error_tamanio db "Tamaño archivo no soportado",10
	largo_error_tamanio equ $ - texto_error_tamanio
	texto_escribir_consola db "Escriba el texto que desee:",10
	largo_escribir_consola equ $ - texto_escribir_consola
	
	output_file_name db "newtext.txt",0						;nombre del archivo que se crea para leer de consola

	cursor dd 0		;el char que se está leyendo
	cant_char_leidos dd 0 	;cantidad de caracteres en el archivo
	enum db ": "
	largo_enum equ $ - enum
	lineas dd 0x30
	largo_lineas equ $ - lineas
	
	blanco db '1',13,10
	largo_blanco equ $ - blanco
	
	file_name db 'myfile.txt'

section .bss

buffer: resb 1000000 				;el buffer 5megabyte (1mb --> 1048 kb)
car: resb 8

fd_out resb 1
fd_in  resb 1					;caracter que se leera desde consola
arch_entrada resd 1

section .text
global _start
_start:
imprimir_inicio:
	mov eax,SYS_W
	mov ebx,STD_OUT 
	mov ecx,texto_inicio
	mov edx,largo_inicio
	int 80h
	jmp control_de_parametros		;Controlo los parametros

control_de_parametros:				;Chequeo de parametros
	pop eax					;Saco primer valor de la pila. Es la cantidad de parametros incluido el nombre del programa
	cmp eax,1				;Lo comparo con uno para saber si hay parametros a demas del nombre
	je cero_parametros			;Si EAX es igual a uno salta a cero_parametros
	cmp eax,2				;Comparo EAX con dos
	je parametro_siguiente			;Si EAX es igual a dos entonces el parametro puede ser la ayuda o el archivo de entrada
	cmp eax,3				;Comparo con 3 para asegurarme de recibir la cantidad máxima de parametros
	jg exceso_parametros			;Si EAX es mayor a 3 salto a error_varios
	je tres_parametros			;Si EAX es igual a 3 entonces tengo dos archivos, uno de entrada y otro de salida
	
cero_parametros:

	mov eax,SYS_W				;Pido al usuario que ingrese su texto por consola 
	mov ebx,STD_OUT
	mov ecx,texto_escribir_consola		
	mov edx,largo_escribir_consola
	int 80h

	mov eax,SYS_CREAT			;Creo un archivo en el que escribire lo ingresado por consola
	mov ebx,output_file_name		;nombre del archivo
	mov ecx,0777				;permisos  				
	int 80h


	mov DWORD[arch_entrada],eax		;Buscar que significa DWORD
	mov ecx,buffer				;Guardo en ecx el buffer donde estara lo leido por consola
	mov esi,0 				;En esi guardo donde empiezo a leer

leer_consola:  
	mov eax,3 				;Servicio sys_read.
	mov ebx,0 				;entrada estandar.
	mov edx,1000000 			;tamaño caracter.
	int 80h 				;invocacion al servicio.
	add ecx,eax
	add esi,eax
	cmp BYTE[buffer + esi - 2],2Dh
	jne leer_consola
	mov ecx,buffer
	
escribir_temporal:
	mov eax,4 				;Servicio sys_write
	mov ebx,DWORD[arch_entrada] 		;Escribe en archivo		
	mov edx,1 				;tamaño del caracter.
	int 80h 				;invocacion al servicio
	dec esi
	cmp esi,0
	inc ecx
	jne escribir_temporal
	
salir:
	mov eax,1 				;servicio sys_exit.
	mov ebx,0 				;Terminacion normal sin errores.
	int 80h 				;invocacion al servicio.

parametro_siguiente:
	pop eax					;nombre programa principal
	pop eax					;Reviso el primer argumento
	mov ebx,eax				;copio la direccion del primer argumento
	;compruebo si el primer argumento es -h
	cmp BYTE [eax], 2Dh			;compruebo si es guion medio
	jne abrir_archivo			;si no es igual se trata de la ruta de archivo
	inc eax					;paso el puntero a la proxima posicion
	cmp BYTE [eax], 68h			;68h es h en hexa
	jne imprimir_ayuda_error		;si no es h el parametro es incorrecto
	inc eax
	cmp BYTE [eax], 0h			;me fijo si no hay nada despues de la h
	jne imprimir_ayuda_error		;hay algo despues de la h, es incorrecto
	jmp imprimir_ayuda			;todo OK, imprimo ayuda sin errores

tres_parametros:
	

exceso_parametros:
	pop eax					;nombre programa principal
	pop eax					;Reviso el primer argumento
	mov ebx,eax				;copio la direccion del primer argumento

abrir_archivo:
	mov eax, SYS_O				;llamo al sitema apertura de archivo
	mov ecx, 0				;no flags
	mov edx, READ_ONLY			;modo solo lectura
	int 80h
	;en el caso de error el descriptor será -1.
	cmp eax,0				;comparo con cero
	jbe error_apertura			;error en el archivo. No se pudo abrir o está vacio. Ya que bien pudo ser 0 o -1
	push eax				;mando el descriptor a la pila. Se utilizará despues para cerrar el archivo
	jmp leer_archivo
	
leer_archivo:
	mov ebx,eax				;la llamada a sistema de read requiere que ebx sea el descriptor del archivo a leer
	mov eax,SYS_R				;llamada a lectura
	mov ecx,buffer				;asigno el buffer de memoria
	mov edx,5242880				;es la longitud máxima soportada por el buffer del programa
	int 80h
	js error_lectura			;si el bit de signo es negativo salgo con error. Se abrio el archivo pero no se pudo leer
	
	cmp eax,5242880				;me aseguro que el archivo no supere al buffer
	jge error_tamanio			;si lo supero salgo con error
	mov [cant_char_leidos],eax		;guardo la cantidad de caracteres para comprobar al final de archivo
	mov eax, SYS_C				;cerrando el archivo
	pop ebx					;saco el descriptor de la pila
	int 80h
	
leer_caracter:
	mov eax,[cursor]			;paso el cursor al registro
	cmp [cant_char_leidos], eax		;comparo si es igual a la cantidad de caracteres leidos
	je sin_errores				;si lo es termino el programa sin errores

	mov ecx, buffer				;comienzo de la posicion inicial del buffer
	add ecx, [cursor]			;le sumo el cursos que parte en 0 que ira aumentando y llevando la posicion

	mov eax, SYS_W				;llamada al sistema
	mov ebx, STD_OUT			;impresion por consola
	mov edx, 1				;un caracter
	int 80h

	inc DWORD [cursor]			;incremento el cursor


	cmp BYTE [ecx],0x0A			;comparo si el caracter impreso es un salto de linea
	;je imprimir_num_linea			;si lo es imprimo dos puntos y espacio

	jmp leer_caracter			;vuelvo a leer otro caracter

error_tamanio:
	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_error_tamanio
	mov edx, largo_error_tamanio
	int 80h
	jmp con_error_uno

error_lectura:
	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_error_rfile
	mov edx, largo_error_rfile
	int 80h
	jmp con_error_uno

error_apertura
 	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_error_ofile
	mov edx, largo_error_ofile
	int 80h
	jmp con_error_uno

imprimir_ayuda:					;imprimo la ayuda de cuando el ingreso de parámetros es correcto
	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_ayuda
	mov edx, largo_ayuda
	int 80h
	jmp sin_errores				;salto a la etiqueta sin_errores

imprimir_ayuda_error:				;imprimo la ayuda cuando el caso de ingreso de parámetros es erroneo
	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_ayuda_error
	mov edx, largo_ayuda_error
	int 80h
	jmp error_varios			;salto a la etiqueta de error_varios

sin_errores:					;No hubo errores en el pasaje de parametros
	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_salida			;Muestro texto de salida correcta
	mov edx, largo_salida
	int 80h
	mov eax, SYS_EXIT			;Salgo del programa
	mov ebx, SIN_ERROR
	int 80h

error_varios:					;Hubo error en el pasaje de parametros
	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_error			;Muestro texto de error
	mov edx, largo_error
	int 80h	
	mov eax, SYS_EXIT			;Salgo del programa
	mov ebx, ERROR_GENERAL
	int 80h

con_error_uno
	mov eax, SYS_W
	mov ebx, STD_OUT
	mov ecx, texto_error
	mov edx, largo_error
	int 80h	
	mov eax, SYS_EXIT
	mov ebx, ERROR_ARCHIVO
	int 80h