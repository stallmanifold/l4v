%
% Copyright 2014, General Dynamics C4 Systems
%
% This software may be distributed and modified according to the terms of
% the GNU General Public License version 2. Note that NO WARRANTY is provided.
% See "LICENSE_GPLv2.txt" for details.
%
% @TAG(GD_GPL)
%

This module contains functions that determine how recoverable faults encountered by user-level threads are propagated to the appropriate fault handlers.

> module SEL4.Kernel.FaultHandler (handleFault) where

\begin{impdetails}

% {-# BOOT-IMPORTS: SEL4.Machine SEL4.Model SEL4.Object.Structures SEL4.API.Failures #-}
% {-# BOOT-EXPORTS: handleFault #-}

> import SEL4.API.Failures
> import SEL4.Machine
> import SEL4.Model
> import SEL4.Object
> import SEL4.Object.Structures(TCB(..))
> import SEL4.Kernel.Thread
> import SEL4.Kernel.CSpace

\end{impdetails}

\subsection{Handling Faults}

Faults generated by the "handleEvent" function (which is defined in \autoref{sec:api.syscall}) are caught and sent to "handleFault", defined below.

The parameters of this function are the fault and a pointer to the thread which requested the kernel operation that generated the fault.

> handleFault :: PPtr TCB -> Fault -> Kernel ()

When a thread faults, the kernel attempts to send a fault IPC to the fault handler endpoint. This has the side-effect of suspending the thread, placing it in the "BlockedOnFault" state until the recipient of the fault IPC replies to it. If the IPC fails, we call "handleDoubleFault" instead.

> handleFault tptr ex = do
>     sendFaultIPC tptr ex `catchFailure` handleDoubleFault tptr ex

\subsection{Sending Fault IPC}

If a thread causes a fault, then an IPC containing details of the fault is sent to a fault handler endpoint specified in the thread's TCB.

> sendFaultIPC :: PPtr TCB -> Fault -> KernelF Fault ()
> sendFaultIPC tptr fault = do

The fault handler endpoint capability is fetched from the TCB.

>     handlerCPtr <- withoutFailure $ threadGet tcbFaultHandler tptr
>     handlerCap <- capFaultOnFailure handlerCPtr False $
>         lookupCap tptr handlerCPtr

>     case handlerCap of

The kernel stores a copy of the fault in the thread's TCB, and performs an IPC send operation to the fault handler endpoint on behalf of the faulting thread. When the IPC completes, the fault will be retrieved from the TCB and sent instead of the message registers.

>         EndpointCap { capEPCanSend = True, capEPCanGrant = canGrant,
>                       capEPCanGrantReply = canGrantReply
>                     } | (canGrant || canGrantReply) ->
>           withoutFailure $ do
>             threadSet (\tcb -> tcb {tcbFault = Just fault}) tptr
>             sendIPC True True (capEPBadge handlerCap)
>                 canGrant True tptr (capEPPtr handlerCap)

If there are insufficient permissions to send to the fault handler, then another fault will be generated.

>         _ -> throw $ CapFault handlerCPtr False $
>             MissingCapability { missingCapBitsLeft = 0 }

\subsection{Double Faults}

> handleDoubleFault :: PPtr TCB -> Fault -> Fault -> Kernel ()

If a fault IPC cannot be sent because the fault handler endpoint capability is missing, then we are left with two faults which cannot be reasonably handled. The faults are both printed to the console for debugging purposes. The faulting thread is placed in the "Inactive" state, which will prevent it running until it is explicitly restarted.

> handleDoubleFault tptr ex1 ex2 = do
>         setThreadState Inactive tptr
>         faultPC <- asUser tptr getRestartPC
>         let errmsg = "Caught fault " ++ (show ex2)
>                 ++ "\nwhile trying to handle fault " ++ (show ex1)
>                 ++ "\nin thread " ++ (show tptr)
>                 ++ "\nat address " ++ (show faultPC)
>         doMachineOp $ debugPrint errmsg


