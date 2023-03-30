public class uploadFileToAWS {

    // Method to get Type of uploaded file
    public string ContentType(string fileType) {
        switch on fileType.toLowerCase() {
            when 'docx' {
                return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            } 
            when 'csv' {
                return 'application/vnd.ms-excel';
            }
            when 'wav' {
                return 'audio/wav';
            }
            when 'wmv' {
                return 'video/x-ms-wmv';
            }
            when 'mp3' {
                return 'audio/mpeg';
            }
            when 'mp4' {
                return 'video/mp4';
            }
            when 'png' {
                return 'image/png';
            }
            when 'pdf' {
                return 'application/pdf';
            }
            when else {
                return 'image/jpeg';
            }
        }
    }


    // Call this method to upload file
    // run below code in aynonums code

    /********
        List<Id> contentVersionList = new List<Id>();
        contentVersionList.add('068Aa000000HgXVIA0');
        System.debug(' contentVersionList ==>' + contentVersionList);
        uploadFileToAWS uafs = new uploadFileToAWS();
        uafs.UploadDocuments(contentVersionList);
    *********/
    
    public void UploadDocuments(List<Id> cvIds) {
        List<ContentVersion> versions=[SELECT VersionData,Title,ContentDocumentId,FileExtension FROM ContentVersion WHERE Id IN: cvIds];
        //Get Named Credential - get configured s3 url
        NamedCredential named=[SELECT DeveloperName, Endpoint FROM NamedCredential where DeveloperName='aws_s3'];
        for(ContentVersion attach:versions) {
            try {
                
                // Creating Multipart Upload
                //String attachmentBody = EncodingUtil.base64Encode(attach.VersionData);
                String formattedDateString = Datetime.now().formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
                String filename = attach.Title;
                String fileExtansion = attach.FileExtension;
                
                HttpRequest req = new HttpRequest();
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/octet-stream');
                req.setEndpoint('callout:aws_s3/test-mv-1/' + filename + '.' + fileExtansion + '?uploads' );
                
                Http http = new Http();
                HTTPResponse res = http.send(req);
                
                String uploadId = '';
                String responseBody = res.getBody();
                if (responseBody != null && responseBody.contains('UploadId')) {
                    uploadId = responseBody.substringBetween('<UploadId>', '</UploadId>');
                }
                
                System.debug('UploadId from response ==> ' + uploadId);
                system.debug('Response Body ------> '+res.getBody());
                system.debug('Response Status code------> '+res.getStatusCode());
                system.debug('Response Status------> '+res.getStatus());
                
                uploadmultipart(attach,uploadId);
                
            } catch (Exception e) {
                System.debug('In the catch block of UploadDocuments ==>');
                System.debug('--Line number ==>' + e.getLineNumber() + '-- Message ==>' + e.getMessage());
                System.debug(e);
            }
        }
    }

    public void uploadmultipart(ContentVersion attach, String uploadid) {

        System.debug('uploadmultipart');
        Integer chunkSize = 7 * 1024 * 1024; // 5 MB
        Blob fileBlob = attach.VersionData;// get the file blob to be uploaded
        //Integer totalChunks = integer.valueOf(Math.ceil(fileBlob.size() / chunkSize));
        Integer totalChunks = integer.valueOf(Math.ceil(Decimal.valueOf(fileBlob.size()).divide(chunkSize, /*digits*/ 1)));
        String presignedUrl = '';
        Integer partNumber =1;
        System.debug('totalChunks size ==>' + totalChunks);

        for (Integer i = 0; i < totalChunks; i++) {
            presignedUrl = 'callout:aws_s3/test-mv-1/' + attach.Title + '.' + attach.FileExtension + '?partNumber=' + partNumber + '&uploadId=' + uploadid;
            Integer chunkStart = i * chunkSize;
            Integer chunkEnd = Math.min((i + 1) * chunkSize - 1, fileBlob.size() - 1);
            Integer chunkLength = chunkEnd - chunkStart + 1;
            
            System.debug('Heap size current ==> ' + Limits.getHeapSize());
            System.debug('Heap size Limit ==> ' + Limits.getLimitHeapSize());

            System.debug('cn ** ==> ' + (totalChunks-1) + ' ** i ==>' + i);

            if(i== (totalChunks-1)) {
	            uploadFileToAWS.submethod(presignedUrl,chunkStart,chunkEnd,attach.VersionData,fileBlob.size(),partNumber,attach.Title,attach.FileExtension,true,uploadid);
            } else {
	            uploadFileToAWS.submethod(presignedUrl,chunkStart,chunkEnd,attach.VersionData,fileBlob.size(),partNumber,attach.Title,attach.FileExtension,false,uploadid);
            }
            partNumber++;
        }
    }
    
    @future(callout=true)
    public static void submethod(String url,Integer start,Integer endd,Blob body,Integer sizeFile,Integer i,String fileName,String FileExe,Boolean flag,String uploadId) {
        
        System.debug('** start ==>' + start + ' -- endd ==>' + endd);
        
        // String attachmentBody = EncodingUtil.base64Encode(body);
        // Blob chunkBlob = EncodingUtil.base64Decode(attachmentBody.mid(start, endd));

        // HttpRequest request = new HttpRequest();
        // request.setMethod('PUT');
        // request.setEndpoint(url);
        // request.setBodyAsBlob(chunkBlob);
        
        // Http http = new Http();
        // HTTPResponse response = http.send(request);


        String attachmentBody = EncodingUtil.base64Encode(body);
        Blob chunkBlob ;
        
        Integer bodyLength = attachmentBody.length();
        Integer chunkSize = 7 * 1024 * 1024; // 5 MB
        Integer partEnd = chunkSize;

        // chunkBlob = EncodingUtil.base64Decode(attachmentBody.substring(start, endd+1));
        chunkBlob = EncodingUtil.base64Decode(attachmentBody.substring(start, endd));

        // for(Integer inc=0; inc<bodyLength; inc+=chunkSize) {
        //     system.debug('inc ==>' + inc + ' --partEnd ==>' + partEnd + ' -- bodyLength ==>' + bodyLength);
        //     if(bodyLength > partEnd) {
        //         // strList.add(str.substring(inc, partEnd));
        //         // System.debug(' Part ==>' + str.substring(inc, partEnd));
        //         chunkBlob = EncodingUtil.base64Decode(attachmentBody.substring(inc, partEnd));
        //         partEnd = partEnd + chunkSize;
        //     } else {
        //         // strList.add(str.substring(inc, bodyLength));
        //         // System.debug(' Part ==>' + str.substring(inc, bodyLength));
        //         chunkBlob = EncodingUtil.base64Decode(attachmentBody.substring(inc, bodyLength));
        //         break;
        //     }

        // }

        HttpRequest request = new HttpRequest();
        request.setMethod('PUT');
        request.setEndpoint(url);
        request.setBodyAsBlob(chunkBlob);

        Http http = new Http();
        HTTPResponse response = http.send(request);

        if (response.getStatusCode() == 200 || response.getStatusCode() == 201) {
            System.debug('response-->' + response);
            String headerEtag = response.getHeader('ETag');
            System.debug('headerEtag-->' + headerEtag);

            System.debug('Chunk ' + i + ' uploaded successfully');
            system.debug(response.getBody());
        } else {
            System.debug('Error uploading chunk ' + i + ': ' + response.getBody());
        }
        
        if(flag){
            completeFile(fileName,FileExe,uploadId, String.valueOf(i));
        }
    }
    
    public static void completeFile(String filename,String fileExtansion,String uploadId, String maxPart) {

        System.debug(' maxPart =>' + maxPart);

        HttpRequest reqLs = new HttpRequest();
        reqLs.setMethod('GET');
        reqLs.setEndpoint('callout:aws_s3/test-mv-1/' + filename + '.' + fileExtansion + '?uploadId=' + uploadId + '&max-parts=' + maxPart + '&part-number-marker=0');
        
        Map<String, String> eTagMap = new Map<String, String>();

        While(String.ValueOf(eTagMap.size()) == maxPart){

            Http httpLs = new Http();
            HTTPResponse resLs = httpLs.send(reqLs);

            system.debug('Response Body ------> '+resLs.getBody());
            system.debug('Status code httpCmp------> '+resLs.getStatusCode());
            system.debug('Status httpCmp------> '+resLs.getStatus());

            String responseBody = resLs.getBody();

            String etagListStr = '';
            if (responseBody != null && responseBody.contains('UploadId')) {
                etagListStr = responseBody.substringBetween('</IsTruncated>', '</ListPartsResult>');
            }
            
            Boolean tracker = true;
            // Map<String, String> eTagMap = new Map<String, String>();
            While(tracker){
                String refPartString = etagListStr.substringBetween('<Part>','</Part>');
                String refPartNumberString = etagListStr.substringBetween('<Part>','</Part>');
                System.debug(refPartString);
                if(refPartString != null && refPartString != ''){
                    eTagMap.put(refPartNumberString.subStringBetween('<PartNumber>','</PartNumber>') ,refPartString.subStringBetween('<ETag>&quot;','&quot;</ETag>'));
                    etagListStr = etagListStr.replace('<Part>' + refPartString + '</Part>','');
                    etagListStr = etagListStr.replace('<PartNumber>' + refPartNumberString + '</PartNumber>','');
                }else{
                    tracker = false;
                }
            }
            System.debug('eTagMap ==>' + eTagMap);
        }
        
        

        HttpRequest reqCmp = new HttpRequest();
        reqCmp.setMethod('POST');
        reqCmp.setEndpoint('callout:aws_s3/test-mv-1/' + filename + '.' + fileExtansion + '?uploadId=' + uploadId);

        String body = '';
        body += '<CompleteMultipartUpload>';
        for(String i: eTagMap.keySet()){
            body += '<Part><PartNumber>'+i+'</PartNumber><ETag>'+eTagMap.get(i)+'</ETag></Part>';
        }
        body += '</CompleteMultipartUpload>';
        system.debug('body ==>' + body);
        reqCmp.setBody(body);
        
        Http httpCmp = new Http();
        HTTPResponse resCmp = httpCmp.send(reqCmp);
        
        system.debug('Status code httpCmp------> '+resCmp.getStatusCode());
        system.debug('Status httpCmp------> '+resCmp.getStatus());
    }
    
}