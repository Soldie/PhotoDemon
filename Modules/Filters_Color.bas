Attribute VB_Name = "Filters_Adjustments"
'***************************************************************************
'Filter (Color Effects) Interface
'Copyright 2000-2019 by Tanner Helland
'Created: 25/January/03
'Last updated: 06/September/12
'Last update: new formulas for all AutoEnhance functions.  Now they are much faster AND they offer much better results.
'
'Runs all color-related filters (invert, negative, shifting, etc.).
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit https://photodemon.org/license/
'
'***************************************************************************

Option Explicit

'Apply basic white-balance correction by stretching the histogram and ignoring pixels above or below
' a 0.05% threshold, followed by lightweight shadow/highlight extraction.
Public Sub AutoCorrectImage()

    Message "Auto-correcting colors and lighting..."
    
    Dim dstSA As SafeArray2D
    EffectPrep.PrepImageData dstSA
    
    'Ensure the image is white-balanced
    Filters_Layers.WhiteBalanceDIB 0.05, workingDIB, True
    
    'To minimize the chance of harm, use a particularly wide gamut for both shadows and highlights
    Filters_Layers.AdjustDIBShadowHighlight 25, 10, -25, 100, 20, 100, 20, workingDIB
    
    'Finalize and render the adjusted image
    EffectPrep.FinalizeImageData
    
End Sub

'Correct white balance by stretching the histogram and ignoring pixels above or below the 0.05% threshold
Public Sub AutoWhiteBalance(Optional ByVal effectParams As String = vbNullString, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As pdFxPreviewCtl)

    If (Not toPreview) Then Message "Adjusting image white balance..."
    
    Dim cParams As pdParamXML
    Set cParams = New pdParamXML
    cParams.SetParamString effectParams
    
    Dim dstSA As SafeArray2D
    EffectPrep.PrepImageData dstSA, toPreview, dstPic
    
    Filters_Layers.WhiteBalanceDIB cParams.GetDouble("threshold", 0.05), workingDIB, toPreview
    
    EffectPrep.FinalizeImageData toPreview, dstPic
    
End Sub

'Invert an image
Public Sub MenuInvert()
        
    Message "Inverting the image..."
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim imageData() As Byte, tmpSA As SafeArray2D
    EffectPrep.PrepImageData tmpSA
    
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    ProgressBars.SetProgBarMax finalY
    progBarCheck = ProgressBars.FindBestProgBarValue()
    
    Dim tmpSA1d As SafeArray1D, pxData As Long, pxStride As Long
    workingDIB.WrapArrayAroundScanline imageData, tmpSA1d, initY
    pxData = tmpSA1d.pvData
    pxStride = tmpSA1d.cElements
    
    'Images are always 32-bpp
    initX = initX * 4
    finalX = finalX * 4
    
    'After all that work, the Invert code itself is very small and unexciting!
    For y = initY To finalY
        tmpSA1d.pvData = pxData + pxStride * y
    For x = initX To finalX Step 4
        imageData(x) = 255 Xor imageData(x)
        imageData(x + 1) = 255 Xor imageData(x + 1)
        imageData(x + 2) = 255 Xor imageData(x + 2)
    Next x
        If (y And progBarCheck) = 0 Then
            If Interface.UserPressedESC() Then Exit For
            ProgressBars.SetProgBarVal y
        End If
    Next y
    
    'Safely deallocate imageData()
    workingDIB.UnwrapArrayFromDIB imageData
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    EffectPrep.FinalizeImageData
    
End Sub

'Shift colors (right or left)
Public Sub MenuCShift(ByVal sType As Byte)
    
    If sType = 0 Then
        Message "Shifting RGB values right..."
    Else
        Message "Shifting RGB values left..."
    End If
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim imageData() As Byte
    Dim tmpSA As SafeArray2D
    EffectPrep.PrepImageData tmpSA
    CopyMemory ByVal VarPtrArray(imageData()), VarPtr(tmpSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim quickVal As Long, qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    progBarCheck = ProgressBars.FindBestProgBarValue()
    
    'Finally, a bunch of variables used in color calculation
    Dim r As Long, g As Long, b As Long
    
    'After all that work, the Invert code itself is very small and unexciting!
    For x = initX To finalX
        quickVal = x * qvDepth
    For y = initY To finalY
        If sType = 0 Then
            r = imageData(quickVal, y)
            g = imageData(quickVal + 2, y)
            b = imageData(quickVal + 1, y)
        Else
            r = imageData(quickVal + 1, y)
            g = imageData(quickVal, y)
            b = imageData(quickVal + 2, y)
        End If
        imageData(quickVal + 2, y) = r
        imageData(quickVal + 1, y) = g
        imageData(quickVal, y) = b
    Next y
        If (x And progBarCheck) = 0 Then
            If Interface.UserPressedESC() Then Exit For
            SetProgBarVal x
        End If
    Next x
        
    'Safely deallocate imageData()
    CopyMemory ByVal VarPtrArray(imageData), 0&, 4
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    EffectPrep.FinalizeImageData
    
End Sub

'Generate a luminance-negative version of the image
Public Sub MenuNegative()

    Message "Calculating film negative values..."

    'Create a local array and point it at the pixel data we want to operate on
    Dim imageData() As Byte
    Dim tmpSA As SafeArray2D
    EffectPrep.PrepImageData tmpSA
    CopyMemory ByVal VarPtrArray(imageData()), VarPtr(tmpSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    ProgressBars.SetProgBarMax finalY
    progBarCheck = ProgressBars.FindBestProgBarValue()
    
    'Finally, a bunch of variables used in color calculation
    Dim r As Long, g As Long, b As Long
    Dim h As Double, s As Double, v As Double
    
    'Apply the filter
    initX = initX * qvDepth
    finalX = finalX * qvDepth
    For y = initY To finalY
    For x = initX To finalX Step qvDepth
        
        'Get red, green, and blue values from the array
        b = imageData(x, y)
        g = imageData(x + 1, y)
        r = imageData(x + 2, y)
        
        'Use those to calculate hue and saturation
        Colors.ImpreciseRGBtoHSL r, g, b, h, s, v
        
        'Convert those HSL values back to RGB, but substitute inverted luminance
        Colors.ImpreciseHSLtoRGB h, s, 1# - v, r, g, b
        
        'Assign the new RGB values back into the array
        imageData(x, y) = b
        imageData(x + 1, y) = g
        imageData(x + 2, y) = r
        
    Next x
        If (y And progBarCheck) = 0 Then
            If Interface.UserPressedESC() Then Exit For
            SetProgBarVal y
        End If
    Next y
        
    'Safely deallocate imageData()
    CopyMemory ByVal VarPtrArray(imageData), 0&, 4
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    EffectPrep.FinalizeImageData
    
End Sub

'Invert the hue of an image
Public Sub MenuInvertHue()

    Message "Inverting image hue..."

    'Create a local array and point it at the pixel data we want to operate on
    Dim imageData() As Byte
    Dim tmpSA As SafeArray2D
    EffectPrep.PrepImageData tmpSA
    CopyMemory ByVal VarPtrArray(imageData()), VarPtr(tmpSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left
    initY = curDIBValues.Top
    finalX = curDIBValues.Right
    finalY = curDIBValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    ProgressBars.SetProgBarMax finalY
    progBarCheck = ProgressBars.FindBestProgBarValue()
    
    'Finally, a bunch of variables used in color calculation
    Dim r As Long, g As Long, b As Long
    Dim h As Double, s As Double, l As Double
    
    'Apply the filter
    initX = initX * qvDepth
    finalX = finalX * qvDepth
    For y = initY To finalY
    For x = initX To finalX Step qvDepth
        
        'Get red, green, and blue values from the array
        b = imageData(x, y)
        g = imageData(x + 1, y)
        r = imageData(x + 2, y)
        
        'Use a fast but somewhat imprecise conversion to HSL.  (Note that this returns hue on the
        ' weird range [-1, 5], which allows for performance optimizations but is not intuitive.)
        Colors.ImpreciseRGBtoHSL r, g, b, h, s, l
        
        'Invert hue
        h = 4# - h
        
        'Convert the newly calculated HSL values back to RGB
        Colors.ImpreciseHSLtoRGB h, s, l, r, g, b
        
        'Assign the new RGB values back into the array
        imageData(x, y) = b
        imageData(x + 1, y) = g
        imageData(x + 2, y) = r
        
    Next x
        If (y And progBarCheck) = 0 Then
            If Interface.UserPressedESC() Then Exit For
            SetProgBarVal y
        End If
    Next y
    
    'Safely deallocate imageData()
    CopyMemory ByVal VarPtrArray(imageData), 0&, 4
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    EffectPrep.FinalizeImageData
    
End Sub

'Isolate the maximum or minimum channel.  Derived from the "Maximum RGB" tool concept in GIMP.
Public Sub FilterMaxMinChannel(ByVal useMax As Boolean)
    
    If useMax Then
        Message "Isolating maximum color channels..."
    Else
        Message "Isolating minimum color channels..."
    End If
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim imageData() As Byte
    Dim tmpSA As SafeArray2D
    EffectPrep.PrepImageData tmpSA
    CopyMemory ByVal VarPtrArray(imageData()), VarPtr(tmpSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left * curDIBValues.BytesPerPixel
    initY = curDIBValues.Top
    finalX = curDIBValues.Right * curDIBValues.BytesPerPixel
    finalY = curDIBValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim qvDepth As Long
    qvDepth = curDIBValues.BytesPerPixel
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    ProgressBars.SetProgBarMax finalY
    progBarCheck = ProgressBars.FindBestProgBarValue()
    
    'Finally, a bunch of variables used in color calculation
    Dim r As Long, g As Long, b As Long, maxVal As Long, minVal As Long
        
    'Apply the filter
    For y = initY To finalY
    For x = initX To finalX Step qvDepth
        
        b = imageData(x, y)
        g = imageData(x + 1, y)
        r = imageData(x + 2, y)
        
        If useMax Then
            maxVal = Max3Int(r, g, b)
            If r < maxVal Then r = 0
            If g < maxVal Then g = 0
            If b < maxVal Then b = 0
        Else
            minVal = Min3Int(r, g, b)
            If r > minVal Then r = 0
            If g > minVal Then g = 0
            If b > minVal Then b = 0
        End If
        
        imageData(x, y) = b
        imageData(x + 1, y) = g
        imageData(x + 2, y) = r
        
    Next x
        If (y And progBarCheck) = 0 Then
            If Interface.UserPressedESC() Then Exit For
            SetProgBarVal y
        End If
    Next y
        
    'Safely deallocate imageData()
    CopyMemory ByVal VarPtrArray(imageData), 0&, 4
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    EffectPrep.FinalizeImageData
    
End Sub

'Automatically enhance image lighting.  Basically, push each pixel's luminance away from the 127 gray point at a
' strength inverse to its distance.  (This function bears strong similarity to the "clarity" quick-fix adjustment.)
' Follow this with a strong shadow/highlight extraction.
Public Sub fxAutoEnhance()

    Message "Auto-enhancing color and lighting..."
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim imageData() As Byte, tmpSA2d As SafeArray2D, tmpSA1d As SafeArray1D
    EffectPrep.PrepImageData tmpSA2d
    
    Dim imgDepth As Long
    imgDepth = curDIBValues.BytesPerPixel
    
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curDIBValues.Left * imgDepth
    initY = curDIBValues.Top
    finalX = curDIBValues.Right * imgDepth
    finalY = curDIBValues.Bottom
    
    'Finally, a bunch of variables used in color calculation
    Dim r As Long, g As Long, b As Long, gray As Long
    
    'Prepare a look-up table for the adjustment.  Clarity is simply a contrast adjustment limited to midtones.
    ' Values at 127 are processed most strongly, with a linear decrease as input values approach 0 or 255.
    ' Also, I reduce the strength of the adjustment by a bit to prevent blowout.
    Dim contrastLookup() As Byte
    ReDim contrastLookup(0 To 255) As Byte
    
    For x = 0 To 255
    
        'The math for this function could be simplified, but as it's only run 256 times, I like to leave it
        ' expanded so I can remember how it works!
        If (x < 127) Then
            gray = x + (x / 127) * (((x - 127) * 50) \ 100) * 0.8
        Else
            gray = x + ((255 - x) / 127) * (((x - 127) * 50) \ 100) * 0.8
        End If
            
        'Crop the lookup value to [0, 255] range
        If (gray > 255) Then
            gray = 255
        ElseIf (gray < 0) Then
            gray = 0
        End If
        
        contrastLookup(x) = gray
    
    Next x
    
    'Apply the filter
    For y = initY To finalY
        workingDIB.WrapArrayAroundScanline imageData, tmpSA1d, y
    For x = initX To finalX Step imgDepth
        
        b = imageData(x)
        g = imageData(x + 1)
        r = imageData(x + 2)
        
        imageData(x) = contrastLookup(b)
        imageData(x + 1) = contrastLookup(g)
        imageData(x + 2) = contrastLookup(r)
        
    Next x
    Next y
    
    workingDIB.UnwrapArrayFromDIB imageData
    
    'With colors enhanced, proceed with shadow/highlight extraction
    Filters_Layers.AdjustDIBShadowHighlight 50, 0, -50, 75, 30, 100, 30, workingDIB
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    EffectPrep.FinalizeImageData

End Sub

'Given an RGBQuad, replace all instances with a different RGBQuad
Public Sub ReplaceColorInDIB(ByRef srcDIB As pdDIB, ByRef oldQuad As RGBQuad, ByRef newQuad As RGBQuad)
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim imageData() As Byte
    Dim tmpSA As SafeArray2D
    PrepSafeArray tmpSA, srcDIB
    CopyMemory ByVal VarPtrArray(imageData()), VarPtr(tmpSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = 0
    initY = 0
    finalX = srcDIB.GetDIBWidth - 1
    finalY = srcDIB.GetDIBHeight - 1
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim quickVal As Long, qvDepth As Long
    qvDepth = srcDIB.GetDIBColorDepth \ 8
    
    'Finally, a bunch of variables used in color calculation
    Dim r As Long, g As Long, b As Long, a As Long
        
    'Apply the filter
    For x = initX To finalX
        quickVal = x * qvDepth
    For y = initY To finalY
        
        b = imageData(quickVal, y)
        g = imageData(quickVal + 1, y)
        r = imageData(quickVal + 2, y)
        a = imageData(quickVal + 3, y)
        
        If (r = oldQuad.Red) And (g = oldQuad.Green) And (b = oldQuad.Blue) And (a = oldQuad.Alpha) Then
        
            imageData(quickVal + 3, y) = newQuad.Alpha
            imageData(quickVal + 2, y) = newQuad.Red
            imageData(quickVal + 1, y) = newQuad.Green
            imageData(quickVal, y) = newQuad.Blue
            
        End If
        
    Next y
    Next x
        
    'Safely deallocate imageData()
    CopyMemory ByVal VarPtrArray(imageData), 0&, 4
    
End Sub
