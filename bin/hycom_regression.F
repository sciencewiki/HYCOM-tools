      PROGRAM HYCOM_REGRESSION
      IMPLICIT NONE
C
C  hycom_regression - Usage:  hycom_regression fin1.a fin2.a idm jdm [offset] fout.a
C
C                 Outputs the least squares linear fit of fin1 to fin2.
C                 Output is s0 (offset) and s1 (slope), for the fit:
C                 fin2 ~= s0 + s1*fin1.
C                 If offset is present the it is the preferred s0, i.e.
C                 this is then a weighted least squares with half the 
C                 total weight given to (0,offset)
C
C  fin*.a is assumed to contain idm*jdm 32-bit IEEE real values for
C   each array, in standard f77 element order, followed by padding
C   to a multiple of 4096 32-bit words, but otherwise with no control
C   bytes/words, and input values of 2.0**100 indicating a data void.
C
C  The output will be a data void if either input file has a data void
C   at that location.
C
C  this version for "serial" Unix systems.
C
C  Alan J. Wallcraft,  Naval Research Laboratory,  July 2004.
C
      REAL*4, ALLOCATABLE :: AX(:,:),AXM(:,:),AXXM(:,:),
     +                       AY(:,:),AYM(:,:),AXYM(:,:)
      REAL*4              :: PAD(4096)
      INTEGER       IOS,L
      INTEGER       IARGC
      INTEGER       NARG
      CHARACTER*240 CARG
C
      LOGICAL       LOFFSET
      INTEGER       IDM,JDM,NPAD
      REAL*4        OFFSET
      CHARACTER*240 CFILE1,CFILE2,CFILEO
C
C     READ ARGUMENTS.
C
      NARG = IARGC()
C
      IF     (NARG.EQ.5) THEN
        CALL GETARG(1,CFILE1)
        CALL GETARG(2,CFILE2)
        CALL GETARG(3,CARG)
        READ(CARG,*) IDM
        CALL GETARG(4,CARG)
        READ(CARG,*) JDM
        CALL GETARG(5,CFILEO)
        LOFFSET = .FALSE.
      ELSEIF (NARG.EQ.6) THEN
        LOFFSET = .TRUE.
        CALL GETARG(1,CFILE1)
        CALL GETARG(2,CFILE2)
        CALL GETARG(3,CARG)
        READ(CARG,*) IDM
        CALL GETARG(4,CARG)
        READ(CARG,*) JDM
        CALL GETARG(5,CARG)
        READ(CARG,*) OFFSET
        CALL GETARG(6,CFILEO)
      ELSE
        WRITE(6,'(3a)')
     &    'Usage:  ',
     &    'hycom_regression',
     &    ' fin1.a fin2.a idm jdm [offset] fout.a'
        CALL EXIT(1)
      ENDIF
C
      NPAD = 4096 - MOD(IDM*JDM,4096)
      IF     (NPAD.EQ.4096) THEN
        NPAD = 0
      ENDIF
C
      ALLOCATE( AX(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_regression: could not allocate ',
     +             IDM*JDM,' words'
        CALL EXIT(2)
      ENDIF
      ALLOCATE( AXM(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_regression: could not allocate ',
     +             IDM*JDM,' words'
        CALL EXIT(2)
      ENDIF
      ALLOCATE( AXXM(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_regression: could not allocate ',
     +             IDM*JDM,' words'
        CALL EXIT(2)
      ENDIF
      ALLOCATE( AY(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_regression: could not allocate ',
     +             IDM*JDM,' words'
        CALL EXIT(2)
      ENDIF
      ALLOCATE( AYM(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_regression: could not allocate ',
     +             IDM*JDM,' words'
        CALL EXIT(2)
      ENDIF
      ALLOCATE( AXYM(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_regression: could not allocate ',
     +             IDM*JDM,' words'
        CALL EXIT(2)
      ENDIF
C
      CALL REGRESSION(AX,AXM,AXXM,AY,AYM,AXYM,IDM,JDM,PAD,NPAD,
     &                LOFFSET,OFFSET, CFILE1,CFILE2,CFILEO)
      CALL EXIT(0)
      END
      SUBROUTINE REGRESSION(AX,AXM,AXXM,AY,AYM,AXYM,IDM,JDM,PAD,NPAD,
     &                      LOFFSET,OFFSET, CFILE1,CFILE2,CFILEO)
      IMPLICIT NONE
C
      REAL*4     SPVAL
      PARAMETER (SPVAL=2.0**100)
C
      CHARACTER*240 CFILE1,CFILE2,CFILEO
      LOGICAL      LOFFSET
      INTEGER      IDM,JDM,NPAD
      REAL*4       AX(IDM,JDM),AXM(IDM,JDM),AXXM(IDM,JDM),
     &             AY(IDM,JDM),AYM(IDM,JDM),AXYM(IDM,JDM),PAD(NPAD),
     &             OFFSET
C
C     MOST OF WORK IS DONE HERE.
C
#ifdef sun
      INTEGER      IR_ISNAN
C
#endif
      CHARACTER*18 CASN
      INTEGER      I,J,IOS,IOUT,IR,NR,NRECL
      REAL*4       AXMN,AXMX,AYMN,AYMX,RNUMR,XAVE,YAVE
#ifdef CRAY
      INTEGER*8    IU8,IOS8
#endif
C
      INQUIRE( IOLENGTH=NRECL) AX,PAD
#ifdef CRAY
#ifdef t3e
      IF     (MOD(NRECL,4096).EQ.0) THEN
        WRITE(CASN,8000) NRECL/4096
 8000   FORMAT('-F cachea:',I4.4,':1:0')
        IU8 = 11
        CALL ASNUNIT(IU8,CASN,IOS8)
        IF     (IOS8.NE.0) THEN
          write(6,*) 'Error: can''t asnunit 11'
          write(6,*) 'ios  = ',ios8
          write(6,*) 'casn = ',casn
          CALL EXIT(5)
        ENDIF
        IU8 = 12
        CALL ASNUNIT(IU8,CASN,IOS8)
        IF     (IOS8.NE.0) THEN
          write(6,*) 'Error: can''t asnunit 12'
          write(6,*) 'ios  = ',ios8
          write(6,*) 'casn = ',casn
          CALL EXIT(5)
        ENDIF
        IU8 = 21
        CALL ASNUNIT(IU8,CASN,IOS8)
        IF     (IOS8.NE.0) THEN
          write(6,*) 'Error: can''t asnunit 21'
          write(6,*) 'ios  = ',ios8
          write(6,*) 'casn = ',casn
          CALL EXIT(5)
        ENDIF
      ENDIF
#else
      CALL ASNUNIT(11,'-F syscall -N ieee',IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t asnunit 11'
        write(6,*) 'ios = ',ios
        CALL EXIT(5)
      ENDIF
      CALL ASNUNIT(12,'-F syscall -N ieee',IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t asnunit 12'
        write(6,*) 'ios = ',ios
        CALL EXIT(5)
      ENDIF
      CALL ASNUNIT(21,'-F syscall -N ieee',IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t asnunit 21'
        write(6,*) 'ios = ',ios
        CALL EXIT(5)
      ENDIF
#endif
#endif
      OPEN(UNIT=11, FILE=CFILE1, FORM='UNFORMATTED', STATUS='OLD',
     +         ACCESS='DIRECT', RECL=NRECL, IOSTAT=IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t open ',TRIM(CFILE1)
        write(6,*) 'ios   = ',ios
        write(6,*) 'nrecl = ',nrecl
        CALL EXIT(3)
      ENDIF
      OPEN(UNIT=12, FILE=CFILE2, FORM='UNFORMATTED', STATUS='OLD',
     +         ACCESS='DIRECT', RECL=NRECL, IOSTAT=IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t open ',TRIM(CFILE2)
        write(6,*) 'ios   = ',ios
        write(6,*) 'nrecl = ',nrecl
        CALL EXIT(3)
      ENDIF
      OPEN(UNIT=21, FILE=CFILEO, FORM='UNFORMATTED', STATUS='NEW',
     +         ACCESS='DIRECT', RECL=NRECL, IOSTAT=IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t open ',TRIM(CFILEO)
        write(6,*) 'ios   = ',ios
        write(6,*) 'nrecl = ',nrecl
        CALL EXIT(3)
      ENDIF
C
C     FIRST FORM SUMS.
C
        DO J= 1,JDM
          DO I= 1,IDM
            AXM( I,J) =  0.0
            AXXM(I,J) =  0.0
            AXYM(I,J) =  0.0
            AYM( I,J) =  0.0
          ENDDO
        ENDDO
C
        NR = -1
        DO IR=1,99999
          READ(11,REC=IR,IOSTAT=IOS) AX
#ifdef ENDIAN_IO
          CALL ENDIAN_SWAP(AX,IDM*JDM)
#endif
          IF     (IOS.NE.0) THEN
            NR = IR-1
          ENDIF
          READ(12,REC=IR,IOSTAT=IOS) AY
#ifdef ENDIAN_IO
          CALL ENDIAN_SWAP(AY,IDM*JDM)
#endif
          IF     (IOS.NE.0) THEN
            IF     (NR.NE.-1) THEN
              EXIT
            ELSE
              WRITE(6,*) 'can''t read record ',IR,' of ',
     &                   TRIM(CFILE2)
              CALL EXIT(4)
            ENDIF
          ENDIF
          DO J= 1,JDM
            DO I= 1,IDM
#ifdef sun
              IF     (IR_ISNAN(AX(I,J)).NE.1 .AND.
     &                IR_ISNAN(AY(I,J)).NE.1      ) THEN
                IF     (AXM(I,J).NE.SPVAL .AND.
     &                  AX( I,J).NE.SPVAL .AND.
     &                  AYM(I,J).NE.SPVAL .AND.
     &                  AY( I,J).NE.SPVAL      ) THEN
                  AXM( I,J) = AXM( I,J) + AX(I,J)
                  AXXM(I,J) = AXXM(I,J) + AX(I,J)*AX(I,J)
                  AXYM(I,J) = AXYM(I,J) + AY(I,J)*AX(I,J)
                  AYM( I,J) = AYM( I,J) + AY(I,J)
                ELSE
                  AXM( I,J) = SPVAL
                  AXXM(I,J) = SPVAL
                  AXYM(I,J) = SPVAL
                  AYM( I,J) = SPVAL
                ENDIF
              ELSE
                AXM( I,J) = SPVAL
                AXXM(I,J) = SPVAL
                AXYM(I,J) = SPVAL
                AYM( I,J) = SPVAL
              ENDIF
#else
              IF     (AXM(I,J).NE.SPVAL .AND.
     &                AX( I,J).NE.SPVAL .AND.
     &                AYM(I,J).NE.SPVAL .AND.
     &                AY( I,J).NE.SPVAL      ) THEN
                AXM( I,J) = AXM( I,J) + AX(I,J)
                AXXM(I,J) = AXXM(I,J) + AX(I,J)*AX(I,J)
                AXYM(I,J) = AXYM(I,J) + AY(I,J)*AX(I,J)
                AYM( I,J) = AYM( I,J) + AY(I,J)
              ELSE
                AXM( I,J) = SPVAL
                AXXM(I,J) = SPVAL
                AXYM(I,J) = SPVAL
                AYM( I,J) = SPVAL
              ENDIF
#endif
            ENDDO !i
          ENDDO !j
        ENDDO !ir
C
        IF     (LOFFSET) THEN
C
C         FAVOR THE INPUT OFFSET BY ADDING NR SAMPLES OF (0.0,OFFSET)
C         WEIGHTED LEAST SQUARES WITH HALF THE WEIGHT AT (0.0,OFFSET)
C
          DO J= 1,JDM
            DO I= 1,IDM
              IF     (AXM(I,J).NE.SPVAL) THEN
*               AXM( I,J) = AXM( I,J) + NR*0.0
*               AXXM(I,J) = AXXM(I,J) + NR*0.0**2
*               AXYM(I,J) = AXYM(I,J) + NR*OFFSET*0.0
                AYM( I,J) = AYM( I,J) + NR*OFFSET
              ENDIF
            ENDDO !i
          ENDDO !j
          NR = 2*NR
        ENDIF
C
C       OFFSET (INTERSEPT) AND SLOPE, IN AY AND AX (RESP.).
C
        RNUMR = 1.0/NR
C
        AXMN =  SPVAL
        AXMX = -SPVAL
        AYMN =  SPVAL
        AYMX = -SPVAL
        DO J= 1,JDM
          DO I= 1,IDM
            IF     (AXM(I,J).NE.SPVAL) THEN
              XAVE    = AXM(I,J)*RNUMR
              YAVE    = AYM(I,J)*RNUMR
              AX(I,J) = (AXYM(I,J) - AXM(I,J)*YAVE) /
     &                  (AXXM(I,J) - AXM(I,J)*XAVE)    !SLOPE (b)
              AY(I,J) = YAVE - AX(I,J)*XAVE            !OFFSET (a)
              AXMN = MIN( AXMN, AX(I,J) )
              AXMX = MAX( AXMX, AX(I,J) )
              AYMN = MIN( AYMN, AY(I,J) )
              AYMX = MAX( AYMX, AY(I,J) )
            ELSE
              AX(I,J) = SPVAL
              AY(I,J) = SPVAL
            ENDIF
          ENDDO
        ENDDO
C
C     OUTPUT THE RESULT.
C
      WRITE(21,REC=1,IOSTAT=IOS) AY
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t write to ',TRIM(CFILEO)
        write(6,*) 'ios = ',ios
        write(6,*) 'rec = ',1
        CALL EXIT(3)
      ENDIF
      WRITE(6,'(a,1p2g16.8)') 'offset: min, max = ',AYMN,AYMX
C
      WRITE(21,REC=2,IOSTAT=IOS) AX
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t write to ',TRIM(CFILEO)
        write(6,*) 'ios = ',ios
        write(6,*) 'rec = ',2
        CALL EXIT(3)
      ENDIF
      WRITE(6,'(a,1p2g16.8)') ' slope: min, max = ',AXMN,AXMX
C
      CLOSE(UNIT=11)
      CLOSE(UNIT=12)
      CLOSE(UNIT=21)
C
      RETURN
      END
