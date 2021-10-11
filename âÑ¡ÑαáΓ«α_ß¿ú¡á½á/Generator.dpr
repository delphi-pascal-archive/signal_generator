program Generator;

uses
  Forms,
  GeneratorUnit in 'GeneratorUnit.pas' {Form1};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'Генератор сигнала';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
