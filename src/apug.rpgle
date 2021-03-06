        
        Ctl-Opt NoMain;
        
        Dcl-Ds C Qualified;
          LT Char(1) Inz('<');
          MT Char(1) Inz('>');
          FS Char(1) Inz('/');
          BS Char(1) Inz('\');
          EQ Char(1) Inz('=');
          SM Char(1) Inz('"');
          QT Char(1) Inz('''');
          CM Char(1) Inz(',');
          OB Char(1) Inz('(');
          CB Char(1) Inz(')');
          DT Char(1) Inz('.');
          P  Char(1) Inz(x'BB'); //Pipe
          HS Char(1) Inz(x'4A'); //hash/pound
          SC Char(1) Inz(x'47');
          SO Char(1) Inz(x'9C');
        End-Ds;
        
        Dcl-C LINE_LEN 512;
        Dcl-C SPACE_LEN 5; //For the int type

        Dcl-C PATH_LEN  128;
        Dcl-C KEY_LEN   128;
        Dcl-C VALUE_LEN 1024;
        
        Dcl-C VAL_LEN  256;
        Dcl-C TAG_LEN  10;
        Dcl-C TAG_LVLS 20;
        
        Dcl-C MODE_TAG  1;
        Dcl-C MODE_PROP 2;
        DCL-C MODE_VAL  3;
        
        Dcl-C MODE_PROP_KEY   4;
        Dcl-C MODE_PROP_VALUE 5;
        
        Dcl-C MODE_VAL_CONST 6;
        Dcl-C MODE_VAL_VAR   7;

        Dcl-Ds Property_T Qualified Template;
          Name  Varchar(10)  Inz('');
          Value Varchar(256) Inz('');
        End-Ds;
        
        Dcl-Ds EachLoop_T Qualified Template;
          AfterSpaces Int(5) Inz(0);  //What index is inside the each loop
          Count       Int(5) Inz(0);  //How many times to loop
          Line        Int(5) Inz(-1); //Restart from here
          
          ArrayName  Varchar(KEY_LEN) Inz(''); //Original array name
          ItemName   Varchar(KEY_LEN) Inz(''); //Temp item name
          CurrentInx Int(5)           Inz(-1);  //Current index
        End-Ds;

        Dcl-DS ClosingTags_T Qualified Template;
          Tag   Varchar(TAG_LEN) Inz('');
          Space Int(SPACE_LEN);
        End-Ds;

        Dcl-Ds Variable_T Qualified;
          Key   Varchar(KEY_LEN);
          Value Varchar(VALUE_LEN);
        End-Ds;
        
        //----------------------------------------------

        Dcl-Ds APUG_Engine_T Qualified Template;
          EachLoop LikeDs(EachLoop_T) Inz; //each keyword
        
          BlockStart   Int(5); //if keyword

          source      Pointer; //Stores file source
          Line        Int(5);  //Current line
        
          ClosingIndx Int(3) Inz(0); //Closing tag index
          ClosingTags LikeDS(ClosingTags_T) Dim(TAG_LVLS); //List of open tags
        
          VarsList Pointer; //Pointer to vars list
          
        
          OUTPUT Varchar(8192) Inz(''); //Result
        End-Ds;
        
        //----------------------------------------------
        
        /copy 'headers/arraylist_h.rpgle'
        
        Dcl-Ds File_Temp Qualified Template;
          PathFile char(PATH_LEN);
          RtvData  char(LINE_LEN);
          OpenMode char(5);
          FilePtr  pointer inz;
        End-ds;
        
        dcl-pr OpenFile pointer extproc('_C_IFS_fopen');
          *n pointer value;  //File name
          *n pointer value;  //File mode
        end-pr;
        
        dcl-pr ReadFile pointer extproc('_C_IFS_fgets');
          *n pointer value;  //Retrieved data
          *n int(10) value;  //Data size
          *n pointer value;  //Misc pointer
        end-pr;
        
        dcl-pr WriteFile pointer extproc('_C_IFS_fwrite');
          *n pointer value;  //Write data
          *n int(10) value;  //Data size
          *n int(10) value;  //Block size
          *n pointer value;  //Misc pointer
        end-pr;
        
        dcl-pr CloseFile extproc('_C_IFS_fclose');
          *n pointer value;  //Misc pointer
        end-pr;
        
        //----------------------------------------------
        
        Dcl-Proc APUG_SetDelims Export;
          Dcl-Pi *N;
            pDelims Char(15) Const;
          End-Pi;
          
          C = pDelims;
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc APUG_Init Export;
          Dcl-Pi *N Pointer End-Pi;
          
          Dcl-S  lPointer Pointer;
          Dcl-Ds engine   LikeDS(APUG_Engine_T) Based(lPointer);
          Dcl-S  lIndex   Int(5);

          lPointer = %Alloc(%Size(APUG_Engine_T));

          //Reset the variables
          
          engine.EachLoop.AfterSpaces = 0;
          engine.EachLoop.Count = 0;
          engine.EachLoop.Line  = -1;
          engine.EachLoop.ArrayName  = '';
          engine.EachLoop.ItemName   = '';
          engine.EachLoop.CurrentInx = -1;
          
          engine.BlockStart = 0;
          engine.ClosingIndx = 0;
          
          For lIndex = 1 to TAG_LVLS;
            engine.ClosingTags(lIndex).Tag = '';
            engine.ClosingTags(lIndex).Space = 0;
          Endfor;
          
          engine.VarsList = arraylist_create();
          engine.source   = arraylist_create();
          
          engine.OUTPUT = '';

          Return lPointer;
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc APUG_Dealloc Export;
          Dcl-Pi *N;
            pEngine Pointer;
          End-Pi;
          
          Dcl-Ds engine   LikeDS(APUG_Engine_T) Based(pEngine);
          
          arraylist_dispose(engine.VarsList);
          arraylist_dispose(engine.source);
          
          Dealloc(NE) pEngine;
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc APUG_AddVar Export;
          Dcl-Pi *N;
            pEngine Pointer;
            pKey    Pointer Value Options(*String);
            pValue  Pointer Value Options(*String);
          End-Pi;

          Dcl-Ds engine   LikeDS(APUG_Engine_T) Based(pEngine);
          Dcl-Ds lVariable LikeDS(Variable_T);
          
          lVariable.Key   = %Str(pKey:KEY_LEN);
          lVariable.Value = %Str(pValue:VALUE_LEN);
          
          arraylist_add(engine.VarsList:
                        %Addr(lVariable):
                        %Size(Variable_T));
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc APUG_Execute Export;
          Dcl-Pi *N Pointer;
            pEngine Pointer;
            pPath   Char(PATH_LEN) Const;
          End-Pi;
          
          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
          Dcl-S lLine  Char(LINE_LEN);
          Dcl-S lIndex Int(3);

          ProcessFile(pEngine:pPath:0);

          If (arraylist_getSize(engine.source) = 0);
            //If there are no lines to process, return blank
            Return %Addr(engine.Output) + 2;
          Endif;

          //Now process all lines
          For engine.Line = 0 to arraylist_getSize(engine.source) - 1;
            lLine = %Str(arraylist_get(engine.source : engine.Line):LINE_LEN);
            ProcessLine(pEngine:lLine);
          Endfor;
          
          //Add the unclosed tags!
          For lIndex = engine.ClosingIndx downto 1;
            engine.OUTPUT += C.LT + C.FS 
                          + engine.ClosingTags(lIndex).Tag + C.MT;
          Endfor;
          
          engine.Output += x'00';
          Return %Addr(engine.Output) + 2;
        
        End-Proc;
        
        //----------------------------------------------

        Dcl-Proc ProcessFile;
          Dcl-Pi *N;
            pEngine Pointer;
            pPath   Char(PATH_LEN) Const;
            pSpaces Int(SPACE_LEN)    Const;
          End-Pi;

          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
          Dcl-Ds pugFile LikeDS(File_Temp);
          Dcl-S  lSpaces Int(5);
        
          pugFile.PathFile = %TrimR(pPath) + x'00';
          pugFile.OpenMode = 'r' + x'00';
          pugFile.FilePtr  = OpenFile(%addr(pugFile.PathFile)
                                     :%addr(pugFile.OpenMode));
        
          If (pugFile.FilePtr = *null);
            engine.OUTPUT = 'Failed to read file: ' + %TrimR(pPath);
          EndIf;
        
          Dow  (ReadFile(%addr(pugFile.RtvData)
                        :%Len(pugFile.RtvData)
                        :pugFile.FilePtr) <> *null);
        
            //End of record null
            //Line feed (LF)
            //Carriage return (CR)
            //Tab
            pugFile.RtvData = SpacePad(pSpaces) 
                            + %xlate(x'00250D05':'    ':pugFile.RtvData);
        
            //include keyword check
            lSpaces = SpaceCount(pugFile.RtvData);
            If (%Subst(pugFile.RtvData:lSpaces+1:7) = 'include');
              ProcessFile(pEngine:%Subst(pugFile.RtvData:lSpaces+9):lSpaces);
            Else;
              arraylist_add(engine.source:
                            %Addr(pugFile.RtvData):
                            %Len(%TrimR(pugFile.RtvData)));
            Endif;

            pugFile.RtvData = ' ';
          Enddo;
        
          CloseFile(pugFile.FilePtr);
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc ProcessLine;
          Dcl-Pi *N;
            pEngine Pointer;
            pLine   Char(LINE_LEN) Value;
          End-Pi;

          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
        
          Dcl-S lSkip     Ind;
          Dcl-S lMode     Int(3);
          Dcl-S lLen      Int(5);
          Dcl-S lIndex    Int(5);
          Dcl-S lChar     Char(1);
          Dcl-S lSpaces   Int(SPACE_LEN);
          Dcl-S lIsCond   Ind;
        
          Dcl-S lPropIdx  Int(3);
          Dcl-S lIsString Ind;
          Dcl-S lPropMode Int(3);
          
          Dcl-S lVarIndx  Int(5);
          Dcl-S lEvalMode Int(3);
        
          Dcl-Ds CurrentElement Qualified;
            Tag        Varchar(TAG_LEN)   Inz('');
            Properties LikeDS(Property_T) Inz Dim(5);
            Value      Varchar(VAL_LEN) Inz('');
          End-Ds;
          
          //Default value for some variables
          
          lLen  = %Len(%TrimR(pLine));
          lMode = MODE_TAG;
          lIsString = *Off;
          lPropIdx  = 1;
          lPropMode = MODE_PROP_KEY;
          lIsCond   = *Off;
          
          lEvalMode  = MODE_VAL_CONST;
          
          // Processing starts below
          
          //No point running the line if it's blank!
          If (pLine = *Blank);
            Return;
          Endif;
        
          lSpaces = SpaceCount(pLine);
          
          //Check if end of each block and go back if possible
          If (engine.EachLoop.AfterSpaces >= lSpaces);
            If (engine.EachLoop.CurrentInx < engine.EachLoop.Count-1);
              //Update temp variable
              engine.EachLoop.CurrentInx += 1;
              engine.Line = engine.EachLoop.Line;
              Return;
                
            Else;
              //Delete temp variable
              engine.EachLoop.AfterSpaces = 0;
            Endif;
          Else;
            If (engine.EachLoop.CurrentInx >= 0);
              pLine = %ScanRpl(engine.EachLoop.ItemName:
                               engine.EachLoop.ArrayName + 
                               '.' + %Char(engine.EachLoop.CurrentInx):
                               pLine:1:
                               lLen + %Len(engine.EachLoop.ArrayName));
              lLen = %Len(%TrimR(pLine));
            Endif;
          Endif;
          
          //Check if we need to close any existing tags.
          For lIndex = engine.ClosingIndx downto 1;
            If (engine.ClosingTags(engine.ClosingIndx).Space >= lSpaces);
              engine.OUTPUT += C.LT + C.FS
                      + engine.ClosingTags(engine.ClosingIndx).Tag + C.MT;
              engine.ClosingIndx -= 1;
            Endif;
          Endfor;
          
          //Check if inside block that cannot run (if statement)
          If (engine.BlockStart <> 0);
            If (lSpaces > engine.BlockStart);
              Return;
            Else;
              engine.BlockStart = 0;
            Endif;
          Endif;
          
          ReplaceConstVars(pEngine:pLine);
          lLen = %Len(%TrimR(pLine));
        
          //Conditional checking
          Select;
            When (%Subst(pLine:lSpaces+1:1) = C.DT); //Dot for class
              CurrentElement.Tag = 'div';
              CurrentElement.Properties(lPropIdx).Name = 'class';
              lMode     = MODE_PROP;
              lPropMode = MODE_PROP_VALUE;
              
              lIsCond   = *On; 
              lSpaces  += 1;
              
            When (%Subst(pLine:lSpaces+1:1) = C.HS); //Hash for ID
              CurrentElement.Tag = 'div';
              CurrentElement.Properties(lPropIdx).Name = 'id';
              lMode     = MODE_PROP;
              lPropMode = MODE_PROP_VALUE;
              
              lIsCond   = *On; 
              lSpaces  += 1;
              
            When (%Subst(pLine:lSpaces+1:1) = C.P); //Pipe
              lChar = %Subst(pLine:lSpaces+2:1);
              
              If (lChar = C.EQ);
                engine.OUTPUT += 
                    GetVarByIndex(pEngine:%TrimR(%Subst(pLine:lSpaces+3)));
              Else;
                engine.OUTPUT += %TrimR(%Subst(pLine:lSpaces+2));
              Endif;
              
              Return;
            
            When (%Subst(pLine:lSpaces+1:2) = C.FS + C.FS);
              Return;
          Endsl;
        
          //Now time to process the line
          For lIndex = (lSpaces+1) to lLen;
            lChar = %Subst(pLine:lIndex:1); //Current character
            lSkip = *Off;
        
            Select;
              When (lMode = MODE_TAG);
                Select;
                  When (lChar = C.OB); //User is adding properties
                    lMode     = MODE_PROP;
                    lPropMode = MODE_PROP_KEY;
        
                  When (lChar = ' '); //Usually means no properties and just a const value!
                    //Check if it's a special keyword
                    If (IsConditionalStatement(CurrentElement.Tag));
                      If (ProcessCondition(pEngine
                                          :CurrentElement.Tag
                                          :%TrimR(%Subst(pLine:lIndex+1))));
                        Select; //Can run block
                          When (CurrentElement.Tag = 'if');
                            engine.BlockStart = 0;
                          When (CurrentElement.Tag = 'each');
                            engine.EachLoop.AfterSpaces = lSpaces;
                            //Create temp var
                        Endsl;
                        
                      Else;
                        Select; //Cannot run block
                          When (CurrentElement.Tag = 'if');
                            engine.BlockStart = lSpaces;
                          When (CurrentElement.Tag = 'each');
                            engine.EachLoop.AfterSpaces = lSpaces;
                        Endsl;
                      Endif;
                      
                      Return;
                    Endif;
                    
                    lMode = MODE_VAL;
                    lEvalMode = MODE_VAL_CONST;
                    
                  When (lChar = C.EQ); //Usually means no properties and just a variable!
                    lMode = MODE_VAL;
                    lEvalMode = MODE_VAL_VAR;
        
                  Other;
                    CurrentElement.Tag += lChar; //Append to the tag name
                Endsl;
        
              When (lMode = MODE_PROP); //We're parsing the properties now!
                Select;
                  When (lChar = C.BS); //Check if the user is added a quote mark
                    If (%Subst(pLine:lIndex+1:1) = C.QT);
                      lSkip = *On;
                    Endif;
        
                  When (lChar = C.QT); //Check if it's the end of a string or the user is adding a quote mark
                    If (%Subst(pLine:lIndex-1:1) <> C.BS);
                      lIsString = NOT lIsString;
                      lSkip = *On;
                    Endif;
        
                  When (lChar = C.CB); //Could be the end of the properties
                    If (lIsString = *Off);
                      lMode = MODE_VAL;
                      
                      lChar = %Subst(pLine:lIndex+1:1);
                      If (lChar = C.EQ); //It's a variable next!
                        lEvalMode =  MODE_VAL_VAR;
                      Else;
                        lEvalMode =  MODE_VAL_CONST;
                      Endif;
                      
                      lIndex += 1;
                      lSkip = *On; //Add nothing, it's the end!
                    Endif;
        
                  When (lChar = C.EQ); //Next is the value to the key!
                    If (lIsString = *Off);
                      lPropMode = MODE_PROP_VALUE;
                      lSkip = *On;
                    Endif;
        
                  When (lChar = C.CM); //Next prop!
                    If (lIsString = *Off);
                      lPropIdx += 1;
                      lPropMode = MODE_PROP_KEY;
                      lSkip = *On;
                    Endif;
                Endsl;
        
                If (lSkip = *Off); //If the character is not blank, append to correct prop variable
                  Select;
                    When (lPropMode = MODE_PROP_KEY);
                      CurrentElement.Properties(lPropIdx).Name += lChar;
                    When (lPropMode = MODE_PROP_VALUE);
                      CurrentElement.Properties(lPropIdx).Value += lChar;
                  Endsl;
                Endif;
        
              When (lMode = MODE_VAL); //Now we're just appending the value!
                CurrentElement.Value += lChar;
            Endsl;
          Endfor;
          
          If (lIsCond);
            lSpaces -= 1;
          Endif;
          
          //Time to generate the output

          engine.OUTPUT += C.LT + CurrentElement.Tag;
          
          //Append proerties if any
          For lIndex = 1 to %Elem(CurrentElement.Properties);
            If (CurrentElement.Properties(lIndex).Name <> *BLANK);
              engine.OUTPUT += ' ' + CurrentElement.Properties(lIndex).Name;
              If (CurrentElement.Properties(lIndex).Value <> *BLANK);
                engine.OUTPUT += C.EQ + C.SM
                       + CurrentElement.Properties(lIndex).Value + C.SM;
              Endif;
            Else;
              Leave;
            Endif;
          Endfor;
      
          If (CurrentElement.Value = *BLANK);
            //Will close in the future.
            engine.ClosingIndx += 1;
            engine.ClosingTags(engine.ClosingIndx).Tag   = CurrentElement.Tag;
            engine.ClosingTags(engine.ClosingIndx).Space = lSpaces; 
            engine.OUTPUT += C.MT;
          Else;
            //Write close tag
            If (lEvalMode = MODE_VAL_CONST);
              engine.OUTPUT += C.MT + %Trim(CurrentElement.Value) 
                             + C.LT + C.FS
                             + CurrentElement.Tag + C.MT;
            Else;
                engine.OUTPUT += C.MT
                       + GetVarByIndex(pEngine:%Trim(CurrentElement.Value))
                       + C.LT + C.FS
                       + CurrentElement.Tag + C.MT;
            Endif;
          Endif;
        
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc VarExists;
          Dcl-Pi *N Int(10);
            pEngine Pointer;
            pKey    Pointer Value Options(*String);
          End-Pi;
          
          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
          
          Dcl-S  lVarPtr   Pointer;
          Dcl-Ds lVariable LikeDS(Variable_T) Based(lVarPtr);
          Dcl-S  lIndex Int(10);
          
          If (arraylist_getSize(engine.VarsList) = 0);
            Return -1;
            
          Else;
            For lIndex = 0 to arraylist_getSize(engine.VarsList) - 1;
              lVarPtr = arraylist_get(engine.VarsList : lIndex);
                If (lVariable.Key = %Str(pKey:KEY_LEN));
                  Return lIndex;
                Endif;
            endfor;
          Endif;
          
          Return -1;
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc GetVarByIndex; 
          Dcl-Pi *N Like(Variable_T.Value);
            pEngine Pointer;
            pKey Pointer Value Options(*String);
          End-Pi;
          
          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
          
          Dcl-S  lVarPtr   Pointer;
          Dcl-Ds lVariable LikeDS(Variable_T) Based(lVarPtr);
          Dcl-S  lIndex    Uns(10);
          
          If (arraylist_getSize(engine.VarsList) = 0);
            Return '';
            
          Else;
            For lIndex = 0 to arraylist_getSize(engine.VarsList) - 1;
              lVarPtr = arraylist_get(engine.VarsList : lIndex);
                If (lVariable.Key = %Str(pKey:KEY_LEN));
                  Return lVariable.Value;
                Endif;
            endfor;
          Endif;
          
          Return '';
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc VarArrayCount;
          Dcl-Pi *N Int(5);
            pEngine Pointer;
            pKey Pointer Value Options(*String);
          End-Pi;
          
          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
          
          Dcl-S  lVarPtr   Pointer;
          Dcl-Ds lVariable LikeDS(Variable_T) Based(lVarPtr);
          
          Dcl-S lLen    Int(3);
          Dcl-S lNumLen Int(3);
          
          Dcl-S lKey        Varchar(KEY_LEN);
          Dcl-S lCurrentKey Varchar(KEY_LEN);
          
          Dcl-S lItem  Int(5);
          Dcl-S lCount Int(5);
          Dcl-S lIndex Uns(10);
          
          lCount = 0;
          lItem  = 0;
          
          lKey = %Str(pKey:KEY_LEN) + '.';
          lLen = %Len(lKey);
          
          If (arraylist_getSize(engine.VarsList) = 0);
            Return 0;
            
          Else;
            lItem = 0;
            For lIndex = 0 to arraylist_getSize(engine.VarsList) - 1;
              lVarPtr = arraylist_get(engine.VarsList : lIndex);
                lNumLen = %Len(%Char(lItem));
                If (%Len(lVariable.Key) >= (lLen + lNumLen));
                  lCurrentKey = %Subst(lVariable.Key:1:lLen + lNumLen);
                  If (lCurrentKey = lKey + %Char(lItem));
                    lCount += 1;
                    lItem  += 1;
                  Endif;
                Endif;
            endfor;
          Endif;
          
          Return lCount;
          
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc IsConditionalStatement;
          Dcl-Pi *N Ind;
            pCondition  Char(TAG_LEN) Const;
          End-Pi;
          
          Return (pCondition = 'if' OR
                  pCondition = 'each'
                 );
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc ProcessCondition;
          Dcl-Pi *N Ind;
            pEngine     Pointer;
            pCondition  Char(TAG_LEN) Const;
            pExpression Pointer Value Options(*String);
          End-Pi;
          
          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
          Dcl-S lCount Int(5);
          
          Select;
            When (pCondition = 'if');
              Return (VarExists(pEngine:pExpression) >= 0);
              
            When (pCondition = 'each');
              //PARSE STUFF
              
              ParseEach(pEngine:pExpression);
              
              lCount = VarArrayCount(pEngine:engine.EachLoop.ArrayName);
              engine.EachLoop.Count = lCount;
              
              If (lCount > 0);
                engine.EachLoop.Line       = engine.Line;
                engine.EachLoop.CurrentInx = 0;
              Endif;
              
              Return (lCount > 0);
          Endsl;
          
          Return *Off;
        End-Proc;
        
        //----------------------------------------------
        
        //each Item in Items
        Dcl-Proc ParseEach;
          Dcl-Pi *N;
            pEngine     Pointer;
            pExpression Pointer;
          End-Pi;
          
          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);

          Dcl-S lPart  Int(3);
          Dcl-S lIndex Int(3);
          Dcl-S lChar  Char(1);
          Dcl-S lParts Varchar(KEY_LEN) Dim(3);
          Dcl-S lValue Varchar(KEY_LEN);
          
          lValue = %Str(pExpression:KEY_LEN);
          lPart = 1;
          
          For lIndex = 1 to %Len(lValue);
            lChar = %Subst(lValue:lIndex:1);
            
            If (lPart >= 4);
              Leave;
            Endif;
            
            If (lChar = ' ');
              lPart += 1;
            Else;
              lParts(lPart) += lChar;
            Endif;
          Endfor;
          
          engine.EachLoop.ItemName  = lParts(1);
          engine.EachLoop.ArrayName = lParts(3);
          
        End-Proc;
        
        //----------------------------------------------

        Dcl-Proc SpaceCount;
          Dcl-Pi *N Int(SPACE_LEN);
            pLine Char(LINE_LEN);
          End-Pi;

          Dcl-S lIndex Int(5);
          Dcl-S lLen   Int(5);
          Dcl-S lChar  Char(1);

          lLen = %Len(%TrimR(pLine));

          For lIndex = 1 to lLen;
            lChar = %Subst(pLine:lIndex:1); //Current character
            If (lChar <> ' ');
              Return lIndex-1;
            Endif;
          Endfor;

          Return 0;
        End-Proc;
        
        //----------------------------------------------

        Dcl-Proc SpacePad;
          Dcl-Pi *N Varchar(LINE_LEN);
            pLength Int(SPACE_LEN) Const;
          End-Pi;

          Dcl-S lResult Varchar(LINE_LEN);
          Dcl-S lIndex  Int(SPACE_LEN);

          lResult = '';
          For lIndex = 1 to pLength;
            lResult += ' ';
          Endfor;

          Return lResult;
        End-Proc;
        
        //----------------------------------------------
        
        Dcl-Proc ReplaceConstVars;
          Dcl-Pi *N;
            pEngine     Pointer;
            pLine       Char(LINE_LEN);
          End-Pi;
          
          Dcl-Ds engine LikeDS(APUG_Engine_T) Based(pEngine);
          Dcl-S  lIndex  Int(5);
          Dcl-S  lLength Int(5);
          Dcl-S  lVar    Varchar(KEY_LEN);
        
          lIndex = %Scan(C.HS + C.SO:pLine);
          Dow (lIndex > 0);
            lIndex += 2; //Move to start of name
            lLength = %Scan(C.SC:pLine:lIndex);
            
            If (lLength > 0);
              lLength -= lIndex;
              
              lVar = %Subst(pLine:lIndex:lLength);
              pLine = %ScanRpl(C.HS + C.SO + lVar + C.SC:
                               GetVarByIndex(pEngine:lVar):pLine);
            Else;
              Leave;
            Endif;
            
            lIndex = %Scan(C.HS + C.SO:pLine);
          Enddo;
        End-Proc;