    include \masm32\include\masm32rt.inc

    .686
    .model  flat,stdcall 
    .xmm 
    option casemap:none 


    includelib \masm32\lib\kernel32.lib
    includelib \masm32\lib\user32.lib
    includelib \masm32\lib\ole32.lib

    include    includes\d3d9.inc
    includelib libs\d3d9.lib
    include    includes\d3d9extra.Inc
    includelib libs\d3d9extra.lib    

DlgProc PROTO :DWORD,:DWORD,:DWORD,:DWORD

;=============================================================
;=============================================================

.data?
align 4
hInstance HINSTANCE ?
Hwnd      dd ?
Hwnd_d3d      dd ?

Screen_Width            dd ?
Screen_Height           dd ?
d3dcaps                 D3DCAPS9 <?>
d3dpp                   D3DPRESENT_PARAMETERS <?>
align 16
Timers                  MEDIATIMERS <?> ; must be 16 bytes aligned!

;****************
.data
align 4
DlgName db "MyDialog",0
g_pD3D                  LPDIRECT3D9 NULL    
g_pD3DDevice            LPDIRECT3DDEVICE9 NULL
g_pPixelShader          LPDIRECT3DPIXELSHADER9 NULL
BackgroundColor         dd  D3DCOLOR_XRGB(0,0,0)
align 16
Screen_Quad             real4 0.0, 0.0, 0.5, 1.0, 0.0, 0.0 ; left top     ( X,Y,Z,W,U,V )
                        real4 0.0, 0.0, 0.5, 1.0, 1.0, 0.0 ; right top    ( X,Y,Z,W,U,V ) 
                        real4 0.0, 0.0, 0.5, 1.0, 0.0, 1.0 ; left bottom  ( X,Y,Z,W,U,V ) 
                        real4 0.0, 0.0, 0.5, 1.0, 1.0, 1.0 ; right bottom ( X,Y,Z,W,U,V )  
                        
PixelShaderConstants    real4 0.0, 0.0, 0.0, 0.0;
ClassName               db 'D3d9 Siekmanski',0
AppName                 db 'Siekmanski PixelShader.',0
include PixelShaders\The road to Hell.Inc


;****************                        
.const
IDB_SHADDER_EFFECT equ 2004


;=============================================================
;=============================================================
.code

;********************** RenderD3d ******************************
align 4
RenderD3d proc
    coinvoke g_pD3DDevice,IDirect3DDevice9,Clear,0,NULL,D3DCLEAR_TARGET or D3DCLEAR_ZBUFFER,BackgroundColor,FLT4(1.0),0

    call    UpdateTimers

    lea     eax,PixelShaderConstants
    movss   xmm0,Timers.Timer1  ; actual time in seconds. (send this to the pixel shader to animate the scene)
    movss   real4 ptr [eax+12],xmm0
    coinvoke g_pD3DDevice,IDirect3DDevice9,SetPixelShaderConstantF,0,addr PixelShaderConstants,1 ; copy constants to the GPU register c0

    coinvoke g_pD3DDevice,IDirect3DDevice9,BeginScene

    coinvoke g_pD3DDevice,IDirect3DDevice9,SetPixelShader,g_pPixelShader ; run Pixel Shader
    coinvoke g_pD3DDevice,IDirect3DDevice9,SetFVF,D3DFVF_XYZRHW or D3DFVF_TEX1 ; current vertex stream declaration
    coinvoke g_pD3DDevice,IDirect3DDevice9,DrawPrimitiveUP,D3DPT_TRIANGLESTRIP,2,addr Screen_Quad,6*4 ; draw the pixel shader result to the background
   
    coinvoke g_pD3DDevice,IDirect3DDevice9,EndScene
    coinvoke g_pD3DDevice,IDirect3DDevice9,Present,NULL,NULL,NULL,NULL ; present it to the window
    ret
RenderD3d endp




;********************** START ******************************
start:
    invoke GetModuleHandle, NULL
    mov    hInstance,eax
    invoke DialogBoxParam, hInstance, ADDR DlgName,Hwnd,addr DlgProc,NULL
    invoke ExitProcess,eax



DlgProc proc hwndX:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM    
LOCAL msg:MSG
    .IF uMsg==WM_INITDIALOG
            invoke GetDlgItem, hwndX,IDB_SHADDER_EFFECT
            cmp     eax,0
            je close_program
            mov     Hwnd_d3d,eax
            ;======== set direct3d9 version ========
            invoke  Direct3DCreate9,D3D_SDK_VERSION
            test    eax,eax
            jz      close_program
            mov     g_pD3D,eax

            coinvoke g_pD3D,IDirect3D9,GetDeviceCaps,D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,addr d3dcaps
            cmp     eax,D3D_OK
            jne     close_program


            ;======== check if video card supports PixelShaderVersion 3.0 =======
            mov     eax,d3dcaps.PixelShaderVersion
            cmp     eax,D3DPS_VERSION(3,0)
            jb      close_program
            
            ;======== initialize the default graphics card ========
            invoke  RtlZeroMemory,offset d3dpp,sizeof d3dpp
            mov     d3dpp.SwapEffect,D3DSWAPEFFECT_DISCARD
            mov     d3dpp.Windowed,TRUE
            
            ;======== create a Depth Buffer =======================
            mov     d3dpp.EnableAutoDepthStencil,TRUE
            mov     d3dpp.AutoDepthStencilFormat,D3DFMT_D24S8 ;D3DFMT_D16
            
            ;======== set a PresentationInterval type =============
            mov     d3dpp.PresentationInterval,D3DPRESENT_INTERVAL_ONE

            ;======= Create a Device ===============================
            coinvoke g_pD3D,IDirect3D9,CreateDevice,D3DADAPTER_DEFAULT,D3DDEVTYPE_HAL,Hwnd_d3d,D3DCREATE_HARDWARE_VERTEXPROCESSING,offset d3dpp,offset g_pD3DDevice
            cmp     eax,D3D_OK
            jne     close_program

            ;=========== create the screen_quad ===============
            mov     eax,600
            cvtsi2ss    xmm0,eax
            mov     eax,240
            cvtsi2ss    xmm1,eax
            lea     eax,Screen_Quad
            movss   real4 ptr[eax+24],xmm0
            movss   real4 ptr[eax+52],xmm1
            movss   real4 ptr[eax+72],xmm0
            movss   real4 ptr[eax+76],xmm1

            ;====  create a shader constant pool for the Pixel Shader viewport ===
            lea     eax,PixelShaderConstants
            movss   real4 ptr[eax],xmm0
            movss   real4 ptr[eax+4],xmm1
            movss   xmm1,FLT4(1.0)
            movss   real4 ptr[eax+8],xmm1

            ;==== Create the pixel shader on the GPU. ====
            coinvoke g_pD3DDevice,IDirect3DDevice9,CreatePixelShader,offset PSC,addr g_pPixelShader
            cmp     eax,D3D_OK
            jne     close_program

            ;===== initialize the timers ======
            invoke  InitTimers,addr Timers,NULL
            
            
    .ELSEIF uMsg==WM_CLOSE
        invoke EndDialog, hwndX,NULL    
    .ELSEIF uMsg==WM_PAINT
        invoke RenderD3d
    .ELSE           
        mov eax,FALSE
        ret
    .ENDIF
    
    mov eax,TRUE
    ret


    ;----------------------
    close_program:
        invoke  MessageBox,hwndX,TEXT_("Sorry, this program will not run on your computer."),TEXT_("ERROR !"),MB_ICONERROR

    close_objects:                  
        SAFE_RELEASE g_pPixelShader
        SAFE_RELEASE g_pD3DDevice
        SAFE_RELEASE g_pD3D        
        ret
    
DlgProc endp
end start

