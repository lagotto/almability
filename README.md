# ALM Report Card

### Description
What are we measuring:
* publisher landing pages for articles
* tool extensible to other landing pages of other scholarly objects and their associated entities

Who is the audience:
* publishers (business decision makers and technical experts)
* platform providers

What is the end goal (why):
* provide best practice list to publishers with instructions on how to make their sites ALMable
* provide a transparent view of the performance of publisher sites

Assumptions:
* most often (should be) resolved by a DOI
* publishers may have multiple publishing platforms
* no distinction between front files and back files for getting representative sampling of publisher pages

### Implementation
* MVP: create a tool that checks a sample of articles based upon a publisher request
    * Front end (Ian, Sara) - three pages
        * home page that takes publisher request
        * publisher report display page
        * performance ranking page
    * Sample size calculation - Scott, Jennifer
    * API (Geof, Martin)
        * input: publisher ID and looks up sample size for publisher (publisher sample map)
        * conducts full set of checks
        * output: JSON results
* CrossRef Labs has agreed to host
* Next phase of development:
    * publisher performance ranking page
    * integrate with CrossRef metadata deposit report card ([Example](http://api.crossref.org/members/98))

Working prototype: [http://almability.crowdometer.org/members/4374/works](http://almability.crowdometer.org/members/4374/works)

### Checks
Problem Level: Severe
* check if it requires a cookie
* check if it fails to resolve after 3 redirects
* check if it never resolves (redirect circle)
* check that it gets to a resource landing page
* check that you receive status code 200
* not a choice page
* not a cookie needed page
* not a error page
* does not return empty content
* check for head request support (i.e., does not return method not allowed)
* check for a canonical URL
* check for support of HTTPS

Problem Level: Moderate
check for completeness of metadata - need more detail
check for Facebook compliance: [Facebook Debugger](https://developers.facebook.com/tools/debug/))

Problem Level: Light
check for general SEO compliance - need more detail
