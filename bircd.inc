{$ifndef mswindows}
  {$define noicon}
  {$define nosignal}
  {$define nodnsapi}
  {$define nowinnt}
{$endif}


{$ifdef mswindows}
  {$ifdef console}
  {$apptype console}
  {$else}
  {$apptype gui}
  {$endif}
{$endif}

