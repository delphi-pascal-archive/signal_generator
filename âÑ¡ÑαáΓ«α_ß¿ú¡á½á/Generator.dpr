program Generator;

uses
  Forms,
  GeneratorUnit in 'GeneratorUnit.pas' {Form1};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := '��������� �������';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
