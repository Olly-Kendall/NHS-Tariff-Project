--create identity column for the HES data episodes by concatenating the hesid and episode number

alter table data.hes2
add Episode_Key varchar(20)

go

update data.hes2
set Episode_Key = concat(hesid, episode)

go

--create procedure returning some individual episode information and calculating it's tariff using the hesid and episode number to form the unique identifier

create proc data.usp_Tariff_Calculator @hesid int, @episode int
as
declare @epikey varchar
set @epikey = concat(@hesid, @episode)
(select
	hesid,
	Episode,
	Epistart,
	Epiend,
	diag_01
	HRG_code,
	(case
		when datepart(year,epistart) >= '2018' then
			(select
				(case
					when admimeth in ('21','22','23','24','25','2A','2B','2C','2D','28') then
						(select
							(case
								when A19.[Non-elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when A19.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and H.epidur in ('0','1')
												and H.admiage >= 19
												and A19.[Non-elective long stay trim point (days)] > 1
												then A19.[Reduced short stay emergency tariff (£)]
											when A19.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and (H.epidur not in ('0','1')
													 or H.admiage < 19
													 or A19.[Non-elective long stay trim point (days)] <= 1)
												then [Non-elective spell tariff (£)]
											when [Reduced short stay emergency tariff _applicable?] = 'No' then [Non-elective spell tariff (£)]
										end)
									 from [stage].[APC1819] A19
									 join data.hes2 H
										on A19.[HRG code] = H.[HRG_code]
									 where Episode_Key = @epikey)
								when A19.[Non-elective long stay trim point (days)] < H.epidur then (A19.[Non-elective spell tariff (£)] + ([Per day long stay payment (for days exceeding trim point) (£)]*(H.epidur - A19.[Non-elective long stay trim point (days)])))
							 end)
						from [stage].[APC1819] A19
						join data.hes2 H
							on A19.[HRG code] = H.[HRG_code]
						where Episode_Key = @epikey)
					when admimeth in ('11','12','13') then
						(select
							(case
								when A19.[Ordinary elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when H.classpat = 2 then
												(select
													(case
														when nullif(A19.[Day case spell tariff (£)],'-') is null then coalesce(cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A19.[Day case spell tariff (£)],'-') is not null then coalesce(cast(replace(A19.[Day case spell tariff (£)],',','')as int), cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1819 A19
												 join data.hes2 H
													on A19.[HRG code] = H.[HRG_code]
												 where Episode_Key = @epikey)
											when H.classpat in ('1','3','4','9') then
												(select
													(case
														when nullif(A19.[Ordinary elective spell tariff (£)],'-') is null then coalesce(cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A19.[Ordinary elective spell tariff (£)],'-') is not null then coalesce(cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int), cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1819 A19
												 join data.hes2 H
													on A19.[HRG code] = H.[HRG_code]
												 where Episode_Key = @epikey)
											else Null
										 end)
									 from data.hes2 H
									 join stage.APC1819 A19
										on H.[HRG_code] = A19.[HRG code]
									 where Episode_Key = @epikey)
								when cast(replace(A19.[Ordinary elective long stay trim point (days)],',','')as int) < cast(replace(H.epidur,',','')as int) then (cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int) + (cast(replace([Per day long stay payment (for days exceeding trim point) (£)],',','')as int)*(cast(replace(H.epidur - A19.[Ordinary elective long stay trim point (days)],',','')as int))))
							 end)
						from [stage].[APC1819] A19
						join data.hes2 H
							on A19.[HRG code] = H.[HRG_code]
						where Episode_Key = @epikey)
					when admimeth not in ('11','12','13','21','22','23','24','25','2A','2B','2C','2D','28') then coalesce(A19.[Combined day case / ordinary elective spell tariff (£)], A19.[Ordinary elective spell tariff (£)])
				end)
			from [stage].[APC1819] A19
			join data.hes2 H
				on A19.[HRG code] = H.[HRG_code])
		when datepart(year,epistart) <= '2017' then
			(select
				(case
					when admimeth in ('21','22','23','24','25','2A','2B','2C','2D','28') then
						(select
							(case
								when A18.[Non-elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when A18.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and H.epidur in ('0','1')
												and H.admiage >= 19
												and A18.[Non-elective long stay trim point (days)] > 1
												then A18.[Reduced short stay emergency tariff (£)]
											when A18.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and (H.epidur not in ('0','1')
													 or H.admiage < 19
													 or A18.[Non-elective long stay trim point (days)] <= 1)
												then A18.[Non-elective spell tariff (£)]
											when A18.[Reduced short stay emergency tariff _applicable?] = 'No' then A18.[Non-elective spell tariff (£)]
										end)
									 from [stage].[APC1718] A18
									 join data.hes2 H
										on A18.[HRG code] = H.[HRG_code]
									 where Episode_Key = @epikey)
								when A18.[Non-elective long stay trim point (days)] < H.epidur then (A18.[Non-elective spell tariff (£)] + (A18.[Per day long stay payment (for days exceeding trim point) (£)]*(H.epidur - A18.[Non-elective long stay trim point (days)])))
							 end)
						from [stage].[APC1718] A18
						join data.hes2 H
							on A18.[HRG code] = H.[HRG_code]
						where Episode_Key = @epikey)
					when admimeth in ('11','12','13') then
						(select
							(case
								when A18.[Ordinary elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when H.classpat = 2 then
												(select
													(case
														when nullif(A18.[Day case spell tariff (£)],'-') is null then coalesce(cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A18.[Day case spell tariff (£)],'-') is not null then coalesce(cast(replace(A18.[Day case spell tariff (£)],',','')as int), cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1718 A18
												 join data.hes2 H
													on A18.[HRG code] = H.[HRG_code]
												 where Episode_Key = @epikey)
											when H.classpat in ('1','3','4','9') then
												(select
													(case
														when nullif(A18.[Ordinary elective spell tariff (£)],'-') is null then coalesce(cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A18.[Ordinary elective spell tariff (£)],'-') is not null then coalesce(cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int), cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1718 A18
												 join data.hes2 H
													on A18.[HRG code] = H.[HRG_code]
												 where Episode_Key = @epikey)
											else Null
										 end)
									 from data.hes2 H
									 join stage.APC1718 A18
										on H.[HRG_code] = A18.[HRG code]
									 where Episode_Key = @epikey)
								when cast(replace(A18.[Ordinary elective long stay trim point (days)],',','')as int) < cast(replace(H.epidur,',','')as int) then (cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int) + (cast(replace(A18.[Per day long stay payment (for days exceeding trim point) (£)],',','')as int)*(cast(replace(H.epidur - A18.[Ordinary elective long stay trim point (days)],',','')as int))))
							 end)
						from [stage].[APC1718] A18
						join data.hes2 H
							on A18.[HRG code] = H.[HRG_code]
						where Episode_Key = @epikey)
					when admimeth not in ('11','12','13','21','22','23','24','25','2A','2B','2C','2D','28') then coalesce(A18.[Combined day case / ordinary elective spell tariff (£)], A18.[Ordinary elective spell tariff (£)])
				end)
			from [stage].[APC1718] A18
			join data.hes2 H
				on A18.[HRG code] = H.[HRG_code]
			where Episode_Key = @epikey)
		end)
from data.hes2 H
join stage.APC1718 A18
	on H.HRG_code = A18.[HRG code]
where Episode_Key = @epikey)

go

--Reformatted HRG data from spreadsheet, adding specific column labels by year making it easier to use in Tableau

select
	 row_number() over (order by [HRG code] asc) [Row_Number19]
	,[HRG code] HRG_Code19
	,left([HRG code],2) HRG_Group19
	,[HRG name] HRG_Name19
	,[Outpatient procedure tariff (£)] Outpatient_Tariff19
	,[Combined day case / ordinary elective spell tariff (£)] [Day_Case/Elective_Tariff19]
	,[Ordinary elective spell tariff (£)] Elective_Tariff19
	,[Ordinary elective long stay trim point (days)] Long_Stay_Elective_Trim19
	,[Non-elective spell tariff (£)] [Non-Elective_Tariff19]
	,[Non-elective long stay trim point (days)] [Long_Stay_Non-Elective_Trim19]
	,[Per day long stay payment (for days exceeding trim point) (£)] [Payment_Per_Day_Over_Trim19]
	,[Reduced short stay emergency tariff _applicable?] [Reduced_Short_Stay_Non-Elective_Tariff_Applicable19]
	,[% applied in calculation of reduced short stay emergency tariff ] [%_of_Non-Elective_Tariff_Reduction19]
	,[Reduced short stay emergency tariff (£)] [Reduced_Non-Elective_Tariff19]
into data.APC19
from stage.APC1819
go
select
	 row_number() over (order by [HRG code] asc) [Row_Number18]
	,[HRG code] HRG_Code18
	,left([HRG code],2) HRG_Group18
	,[HRG name] HRG_Name18
	,[Outpatient procedure tariff (£)] Outpatient_Tariff18
	,[Combined day case / ordinary elective spell tariff (£)] [Day_Case/Elective_Tariff18]
	,[Ordinary elective spell tariff (£)] Elective_Tariff18
	,[Ordinary elective long stay trim point (days)] Long_Stay_Elective_Trim18
	,[Non-elective spell tariff (£)] [Non-Elective_Tariff18]
	,[Non-elective long stay trim point (days)] [Long_Stay_Non-Elective_Trim18]
	,[Per day long stay payment (for days exceeding trim point) (£)] [Payment_Per_Day_Over_Trim18]
	,[Reduced short stay emergency tariff _applicable?] [Reduced_Short_Stay_Non-Elective_Tariff_Applicable18]
	,[% applied in calculation of reduced short stay emergency tariff ] [%_of_Non-Elective_Tariff_Reduction18]
	,[Reduced short stay emergency tariff (£)] [Reduced_Non-Elective_Tariff18]
into data.APC18
from stage.APC1718

go

--convert outpatient data to int to allow processing in Tableau

update data.apc18
set [Outpatient_Tariff18] = cast(replace(isnull([Outpatient_Tariff18],'-'),',','') as int)
update data.apc19
set [Outpatient_Tariff19] = cast(replace(isnull([Outpatient_Tariff19],'-'),',','') as int)

--create a new table with average increase values

select
	 a8.HRG_code18
	,a9.HRG_code19
	,s.[HRG subchapter]
	,s.[HRG chapter]
	,avg((a9.[Non-Elective_Tariff19]-a8.[Non-Elective_Tariff18])/nullif(a8.[Non-Elective_Tariff18],0)*100) over (partition by s.[HRG subchapter]) Subchapter_AVG
	,avg((a9.[Non-Elective_Tariff19]-a8.[Non-Elective_Tariff18])/nullif(a8.[Non-Elective_Tariff18],0)*100) over (partition by s.[HRG chapter]) Chapter_AVG
into stage.editdata
from data.APC18 a8
join data.APC19 a9
	on a8.HRG_Code18 = a9.HRG_Code19
join stage.[HRG_Subchapter] s
	on a9.HRG_Group19 = s.[HRG Subchapter]

go

--Add columns to the HRG chapter and subchapter tables containing grouped average values

alter table stage.HRG_Chapter
add Chapter_AVG int
go
alter table stage.hrg_subchapter
add Subchapter_AVG int
go
update stage.HRG_chapter
   set [HRG_chapter].chapter_AVG = (select distinct editdata.chapter_AVG from stage.editdata
 where HRG_Chapter.[HRG Chapter] = editdata.[HRG chapter])
go
update stage.HRG_Subchapter
   set [HRG_subchapter].subchapter_AVG = (select distinct editdata.Subchapter_AVG from stage.editdata
 where HRG_Subchapter.[HRG Subchapter] = editdata.[HRG subchapter])

 go

 --create new table to be used by radial bar chart in tableau

 select distinct
	 c.[HRG chapter]
	,s.[HRG subchapter]
	,c.[HRG Chapter Description]
	,s.[HRG subchapter description]
	,e.chapter_AVG
	,e.subchapter_AVG
into data.radialdata
from stage.HRG_Chapter c
join stage.HRG_Subchapter s
	on c.[HRG Chapter] = s.[HRG Chapter]
join stage.editdata e
	on s.[HRG Subchapter] = e.[HRG subchapter]

go

--Calculate total average tariff increase (%) for admitted patients and outpatients across all HRG codes

with cte as
(
select
	 sum(a19.[Day_Case/Elective_Tariff19]) e19
	,sum(a18.[Day_Case/Elective_Tariff18]) e18
	,sum(cast(replace(isnull(a18.[Outpatient_Tariff18],'-'),',','') as float)) o18
	,sum(cast(replace(isnull(a19.[Outpatient_Tariff19],'-'),',','') as float)) o19
	,sum(cast(replace(isnull(a18.[Non-Elective_Tariff18],'-'),',','') as float)) ne18
	,sum(cast(replace(isnull(a19.[Non-Elective_Tariff19],'-'),',','') as float)) ne19
from data.APC18 a18
join data.APC19 a19
	on a18.HRG_Code18 = a19.HRG_Code19
)
select
	(((e19+o19+ne19)-(e18+o18+ne18))/(e18+o18+ne18))*100
from cte

go

--Insert HRG codes into HES data from randomly generated positions

alter table data.hes2
add HRG_code2 varchar(10)
go
update data.hes2
set HRG_code2 =
(select distinct
	h.HRG_code
from data.HES_with_HRG h
join data.hes2 h2
	on h.hesid = h2.hesid
where h.hesid = h2.hesid)

--Add an identity row to the HES data to be used in the tariff calculations

alter table data.hes2
add rowno int identity

go

--Add empty Tariff column to HES table

alter table data.hes2
add Tariff int

go

--Procedure for adding tariffs to HES table for episodes based on relevant criteria

create proc data.usp_Table_Tariff
as
declare @rowno int
 
declare com cursor local fast_forward for
	select @rowno
	from stage.HESdata2
	order by rowno
open com
 
fetch next from com into @rowno
 
while @@FETCH_STATUS = 0
begin

set @rowno = (select top 1 rowno from data.hes2 where tariff is null order by rowno)
update data.hes2
set Tariff =
(select
	(case
		when datepart(year,epistart) >= '2018' then
			(select
				(case
					when admimeth in ('21','22','23','24','25','2A','2B','2C','2D','28') then
						(select
							(case
								when A19.[Non-elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when A19.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and H.epidur in ('0','1')
												and H.admiage >= 19
												and A19.[Non-elective long stay trim point (days)] > 1
												then A19.[Reduced short stay emergency tariff (£)]
											when A19.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and (H.epidur not in ('0','1')
													 or H.admiage < 19
													 or A19.[Non-elective long stay trim point (days)] <= 1)
												then [Non-elective spell tariff (£)]
											when [Reduced short stay emergency tariff _applicable?] = 'No' then [Non-elective spell tariff (£)]
										end)
									 from [stage].[APC1819] A19
									 join data.hes2 H
										on A19.[HRG code] = H.[HRG_code]
									 where rowno = @rowno)
								when A19.[Non-elective long stay trim point (days)] < H.epidur then (A19.[Non-elective spell tariff (£)] + ([Per day long stay payment (for days exceeding trim point) (£)]*(H.epidur - A19.[Non-elective long stay trim point (days)])))
							 end)
						from [stage].[APC1819] A19
						join data.hes2 H
							on A19.[HRG code] = H.[HRG_code]
						where rowno = @rowno)
					when admimeth in ('11','12','13') then
						(select
							(case
								when A19.[Ordinary elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when H.classpat = 2 then
												(select
													(case
														when nullif(A19.[Day case spell tariff (£)],'-') is null then coalesce(cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A19.[Day case spell tariff (£)],'-') is not null then coalesce(cast(replace(A19.[Day case spell tariff (£)],',','')as int), cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1819 A19
												 join data.hes2 H
													on A19.[HRG code] = H.[HRG_code]
												 where rowno = @rowno)
											when H.classpat in ('1','3','4','9') then
												(select
													(case
														when nullif(A19.[Ordinary elective spell tariff (£)],'-') is null then coalesce(cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A19.[Ordinary elective spell tariff (£)],'-') is not null then coalesce(cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int), cast(replace(A19.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1819 A19
												 join data.hes2 H
													on A19.[HRG code] = H.[HRG_code]
												 where rowno = @rowno)
											else Null
										 end)
									 from data.hes2 H
									 join stage.APC1819 A19
										on H.[HRG_code] = A19.[HRG code]
									 where rowno = @rowno)
								when cast(replace(A19.[Ordinary elective long stay trim point (days)],',','')as int) < cast(replace(H.epidur,',','')as int) then (cast(replace(A19.[Ordinary elective spell tariff (£)],',','')as int) + (cast(replace([Per day long stay payment (for days exceeding trim point) (£)],',','')as int)*(cast(replace(H.epidur - A19.[Ordinary elective long stay trim point (days)],',','')as int))))
							 end)
						from [stage].[APC1819] A19
						join data.hes2 H
							on A19.[HRG code] = H.[HRG_code]
						where rowno = @rowno)
					when admimeth not in ('11','12','13','21','22','23','24','25','2A','2B','2C','2D','28') then coalesce(A19.[Combined day case / ordinary elective spell tariff (£)], A19.[Ordinary elective spell tariff (£)])
				end)
			from data.hes2 H
			join stage.APC1819 A19
				on H.HRG_code = A19.[HRG code])
		when datepart(year,epistart) <= '2017' then
			(select
				(case
					when admimeth in ('21','22','23','24','25','2A','2B','2C','2D','28') then
						(select
							(case
								when A18.[Non-elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when A18.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and H.epidur in ('0','1')
												and H.admiage >= 19
												and A18.[Non-elective long stay trim point (days)] > 1
												then A18.[Reduced short stay emergency tariff (£)]
											when A18.[Reduced short stay emergency tariff _applicable?] = 'Yes'
												and (H.epidur not in ('0','1')
													 or H.admiage < 19
													 or A18.[Non-elective long stay trim point (days)] <= 1)
												then A18.[Non-elective spell tariff (£)]
											when A18.[Reduced short stay emergency tariff _applicable?] = 'No' then A18.[Non-elective spell tariff (£)]
										end)
									 from [stage].[APC1718] A18
									 join data.hes2 H
										on A18.[HRG code] = H.[HRG_code]
									 where rowno = @rowno)
								when A18.[Non-elective long stay trim point (days)] < H.epidur then (A18.[Non-elective spell tariff (£)] + (A18.[Per day long stay payment (for days exceeding trim point) (£)]*(H.epidur - A18.[Non-elective long stay trim point (days)])))
							 end)
						from [stage].[APC1718] A18
						join data.hes2 H
							on A18.[HRG code] = H.[HRG_code]
						where rowno = @rowno)
					when admimeth in ('11','12','13') then
						(select
							(case
								when A18.[Ordinary elective long stay trim point (days)] >= H.epidur then
									(select
										(case
											when H.classpat = 2 then
												(select
													(case
														when nullif(A18.[Day case spell tariff (£)],'-') is null then coalesce(cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A18.[Day case spell tariff (£)],'-') is not null then coalesce(cast(replace(A18.[Day case spell tariff (£)],',','')as int), cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1718 A18
												 join data.hes2 H
													on A18.[HRG code] = H.[HRG_code]
												 where rowno = @rowno)
											when H.classpat in ('1','3','4','9') then
												(select
													(case
														when nullif(A18.[Ordinary elective spell tariff (£)],'-') is null then coalesce(cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int), cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int))
														when nullif(A18.[Ordinary elective spell tariff (£)],'-') is not null then coalesce(cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int), cast(replace(A18.[Combined day case / ordinary elective spell tariff (£)],',','')as int))
													 end)
												 from stage.APC1718 A18
												 join data.hes2 H
													on A18.[HRG code] = H.[HRG_code]
												 where rowno = @rowno)
											else Null
										 end)
									 from data.hes2 H
									 join stage.APC1718 A18
										on H.[HRG_code] = A18.[HRG code]
									 where rowno = @rowno)
								when cast(replace(A18.[Ordinary elective long stay trim point (days)],',','')as int) < cast(replace(H.epidur,',','')as int) then (cast(replace(A18.[Ordinary elective spell tariff (£)],',','')as int) + (cast(replace(A18.[Per day long stay payment (for days exceeding trim point) (£)],',','')as int)*(cast(replace(H.epidur - A18.[Ordinary elective long stay trim point (days)],',','')as int))))
							 end)
						from [stage].[APC1718] A18
						join data.hes2 H
							on A18.[HRG code] = H.[HRG_code]
						where rowno = @rowno)
					when admimeth not in ('11','12','13','21','22','23','24','25','2A','2B','2C','2D','28') then coalesce(A19.[Combined day case / ordinary elective spell tariff (£)], A19.[Ordinary elective spell tariff (£)])
				end)
			from data.hes2 H
			join stage.APC1718 A18
				on H.HRG_code = A18.[HRG code])
		end)
from data.hes2 H
join stage.APC1819 A19
	on H.HRG_code = A19.[HRG code]
where rowno = @rowno)
where rowno = @rowno
fetch next from com into @rowno
end
 
close com
deallocate com

go

--run procedure to populate table with values

exec data.usp_Table_Tariff