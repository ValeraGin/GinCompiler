unit AboutFormUnit;

{$reference 'System.Windows.Forms.dll'}
{$reference 'System.Drawing.dll'}

{$resource 'resources\about.png'}
{$resource 'resources\header.png'}

uses
  System,
  System.Drawing,
  System.Collections,
  System.ComponentModel,
  System.Windows.Forms,
  
  CommonUnit;

type
  AboutForm = class(Form)
  private 
    Header: PictureBox;
    LinkPage, LinkForum: LinkLabel;
    VersionLabel, CopyrightLabel: &Label;
    procedure InitControls;
    procedure LinkClicked(sender: object; args: LinkLabelLinkClickedEventArgs);
    begin
      (sender as LinkLabel).Links[(sender as LinkLabel).Links.IndexOf(args.Link)].Visited := true;
      var URL := (args.Link.LinkData as string);
      if (URL <> nil) and URL.StartsWith('http://') then
      begin
        System.Diagnostics.Process.Start(URL);
      end;
    end;
  public 
    constructor Create;
    begin
      InitControls;
    end;
  end;

procedure AboutForm.InitControls;
begin
  var g := Bitmap.FromStream(GetResourceStream('about.png')) as Bitmap;
  Icon := System.Drawing.Icon.FromHandle(g.GetHicon);
  
  Text := 'О программе';
  Size := new Drawing.Size(290, 305);
  FormBorderStyle := System.Windows.Forms.FormBorderStyle.FixedSingle;
  MaximizeBox := False;
  MinimizeBox := False;
  Header := new PictureBox;
  Header.Size := new Drawing.Size(290, 77);
  Header.Image := Image.FromStream(GetResourceStream('header.png'));
  Controls.Add(Header);
  
  LinkPage := new LinkLabel;
  LinkPage.AutoSize := True;
  LinkPage.Text := 'Страница в интернете';
  LinkPage.Links.Add(0, LinkPage.Text.Length, 'http://ignatkovich.su/html-version/index.shtml');
  LinkPage.LinkClicked += LinkClicked;
  LinkPage.Location := new Point(12, 90);
  Controls.Add(LinkPage);
  
  LinkForum := new LinkLabel;
  LinkForum.AutoSize := True;
  LinkForum.Text := 'Обсуждение программы';
  LinkForum.Links.Add(0, LinkForum.Text.Length, 'http://it.mmcs.rsu.ru/forum?func=view&id=37741&catid=27&limit=10&limitstart=0');
  LinkForum.LinkClicked += LinkClicked;
  LinkForum.Location := new Point(12, 117);
  Controls.Add(LinkForum);
  
  
  VersionLabel := new &Label;
  VersionLabel.AutoSize := True;
  VersionLabel.Text := 'Версия ' + Version;
  VersionLabel.Location := new Point(12, 215);
  Controls.Add(VersionLabel);
  
  CopyrightLabel := new &Label;
  CopyrightLabel.AutoSize := True;
  CopyrightLabel.Text := 'Copyright (c) 2010-2011 ValeraGin';
  CopyrightLabel.Location := new Point(12, 238);
  Controls.Add(CopyrightLabel);
end;


begin
end. 